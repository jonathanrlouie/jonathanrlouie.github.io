---
layout: post
title:  Issues with Env-IO
date:   2019-08-31 22:00:00 -0700
categories: Rust, ZIO, Env-IO, monad, Scala
---

Last month, I mentioned that I would write about some of the issues I ran into with Env-IO, so I decided that I would write about those issues this month. Since I only really spent the beginning of the month working on Env-IO, next month\'s post will probably be about something different (and more exciting). 

# Variance

One of the major issues I struggled with when trying to port ZIO to Rust was subtyping. ZIO works quite well with Scala\'s subtyping rules, using them to enforce correct usage of the library. Unfortunately, we don\'t have the ability to leverage subtyping in Rust, so I ended up enforcing these constraints in other ways. I am still using some of the type aliases defined originally in ZIO, but there are some key differences:

```rust
pub enum NoReq {}
pub enum Nothing {}

pub type UIO<A> = EnvIO<NoReq, A, Nothing>;

impl<A: 'static> UIO<A> {
    pub fn into_envio<R: 'static, E: 'static>(self) -> EnvIO<R, A, E> {
        EnvIO {
            instr: self.instr,
            _pd: PhantomData,
        }
    }
}
```

In this case, Nothing is an empty type like the currently unstable `!`. I will explain NoReq later. In this case, I needed to define some way of converting an `EnvIO` with no possibility of failure into an `EnvIO` that can potentially fail. Without this transformation, certain combinators, such as `and_then`, cannot be used. Let\'s take a look at how that\'s defined:

```rust
pub fn and_then<B, K: Fn(A) -> EnvIO<NoReq, B, E> + 'static>(self, k: K) -> REnvIO<R, B, E> {
    REnvIO {
        envio: self.envio.and_then(k),
    }
}
```

The important part here to notice is the signature of the function we are passing in. It must return another `EnvIO` such that the error type is the same as the source type. This is a problem when we get a `UIO` because it means that the function passed to `and_then` also needs to return a `UIO`. This is not at all how ZIO works, which is why `into_envio` was added in Env-IO. Now, if you have a `UIO`, you can easily convert it to an `EnvIO` of the correct error type for `and_then`. Of course, this is a bit less ergonomic and non-trivially changes the API.

While the aforementioned solution works decently for introducing the error type, it won\'t be sufficient for introducing the environment type. For the environment type, we need to use a newtype wrapper to ensure that our API is sound. Let\'s take a look at the code:

```rust
pub struct REnvIO<R, A, E> {
    envio: EnvIO<R, A, E>,
}

impl<R: 'static, A: 'static, E: 'static> REnvIO<R, A, E> {
    pub fn and_then<B, K: Fn(A) -> EnvIO<NoReq, B, E> + 'static>(self, k: K) -> REnvIO<R, B, E> {
        REnvIO {
            envio: self.envio.and_then(k),
        }
    }

    pub fn map<B: 'static, F: Fn(A) -> B + 'static>(self, f: F) -> REnvIO<R, B, E> {
        REnvIO {
            envio: self.envio.map(f),
        }
    }

    pub fn fold<S: 'static, F: 'static, B: 'static>(
        self,
        success: S,
        failure: F,
    ) -> REnvIO<R, B, Nothing>
    where
        S: Fn(A) -> B,
        F: Fn(E) -> B,
    {
        REnvIO {
            envio: self.envio.fold(success, failure),
        }
    }

    pub fn provide(self, r: R) -> IO<A, E> {
        provide(r)(self.envio)
    }
}

fn provide<R: 'static, A: 'static, E: 'static>(r: R) -> impl FnOnce(EnvIO<R, A, E>) -> IO<A, E> {
    move |envio: EnvIO<R, A, E>| EnvIO {
        instr: Instr::Provide(Box::new(r), box_instr(envio)),
        _pd: PhantomData,
    }
}

pub fn environment<R: 'static>() -> REnvIO<R, R, Nothing> {
    REnvIO {
        envio: EnvIO {
            instr: Instr::Read(KleisliOrFold::Kleisli(Box::new(move |bany: BAny| {
                box_instr(succeed(downcast::<R>(bany)))
            }))),
            _pd: PhantomData,
        },
    }
}
```

As you can see, this creates a lot of boilerplate. We need to use composition to call the inner `EnvIO`\'s methods. The environment is where `NoReq` comes in. Normally, in ZIO, `Any` is used instead. Again, because we don\'t have subtyping in Rust, `NoReq` is used instead as a marker to indicate that an environment is not required for a particular instruction. Now, we can enforce that our interpreter takes an `EnvIO` with no required environment. This is important because we don\'t want to run an `EnvIO` that is waiting for the user to provide it with an environment, otherwise we will have to `panic!`. the reason why we need a newtype instead of a type alias is because the user can pick the type that `environment` uses when constructing an `EnvIO`. If the user were to pick `NoReq` and then pass the resulting `EnvIO` to the interpreter, the interpreter would try to read an environment from the environment stack and `panic!`. Thus, we need to ensure that the `EnvIO` transitions to a new type state and transitions back when calling `provide`.

This newtype wrapper also complicates the API for the `IO` alias, since we now have to add a new `and_then_req` method in the case where we want to pass a function that returns a `REnvIO` instead:

```rust
impl<A: 'static, E: 'static> IO<A, E> {
    pub fn with_env<R: 'static>(self) -> EnvIO<R, A, E> {
        EnvIO {
            instr: self.instr,
            _pd: PhantomData,
        }
    }

    pub fn and_then_req<R: 'static, B, K: Fn(A) -> REnvIO<R, B, E> + 'static>(
        self,
        k: K,
    ) -> REnvIO<R, B, E> {
        REnvIO {
            envio: EnvIO {
                instr: Instr::AndThen(
                    box_instr(self),
                    KleisliOrFold::Kleisli(Box::new(move |bany: BAny| {
                        box_instr(k(downcast::<A>(bany)).envio)
                    })),
                ),
                _pd: PhantomData,
            },
        }
    }
}
```

As with `UIO`\'s `into_envio`, we add a `with_env` method to easily convert to an `EnvIO`, at the cost of slightly worse ergonomics.

# Ownership

Note that there are no `access` or `access_m` methods here, unlike ZIO. This is because we are taking ownership of the environment. While it might be possible to borrow the environment, I found it too difficult to come up with a way to do this. As a result, the API is a bit simpler, but also a fair bit less ergonomic. At the very least, I do not have to worry about bracketing to drop allocated resources, since Rust uses RAII.

# Closing thoughts

At this point it\'s pretty clear how much better this approach synergizes with Scala compared to Rust. While it is definitely possible to work around the lack of subtyping in Rust, the API for Env-IO ends up being less ergonomic and requires a bit of boilerplate on my part as the library author. However, I feel like it is still usable even in its current state. Of course, Scala also has the cake pattern, which helps make environments more ergonomic to use. That\'s an issue I have not found a workaround for yet in Rust. Perhaps once more compiler features are added/stabilized in Rust, it will be possible to make Env-IO more suitable for Rust, but for now, I think this is about as far as I\'m willing to push this project.