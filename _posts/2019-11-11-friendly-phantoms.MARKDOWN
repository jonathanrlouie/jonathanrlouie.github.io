---
layout: post
title:  "Friendly Phantoms"
date:   2019-11-11 20:00:00 -0700
categories: Rust, functional programming, Haskell, Scala
---

I can't keep up with my blog! Halp! On the other hand, I've been asked on two separate occasions to present a talk on monads, since people really seem to like my explanations. Thus, the blog has kind of taken the backseat. I will try to stay on top of this thing as best as I can, though! I've actually been meaning to write more about randomizers again, but I will need some time to prepare the material for it.

Recently, I read a paper called [Ghosts of Departed Proofs](https://kataskeue.com/gdp.pdf). It's a Haskell paper, but I found that I could translate most of the concepts to Rust. I've been meaning to write about this for a while, but haven't really had time to do so. Since I recently did a presentation on this topic, I felt that now was as good a time as any.

# Ghosts of Departed Proofs

To motivate this technique, let's revisit smart constructors. I have [previously written](https://jonathanrlouie.github.io/rust,/functional/programming,/mini-rando/2019/01/01/functional-filler.html) about the usage of smart constructors to remove invalid states from programs. While this does give us added type-safety, the additional `Option` wrapper can slow down our code and also make it less ergonomic. Ideally, we would like to be able to express to the compiler that there is no need for an `Option` in some cases, since we can prove that the input is already valid. Fortunately, there are ways to do this through type-level programming, such as the GDP technique.

Before we can use GDP, we will need some way of expressing rank-N types in Rust. While they aren't currently supported in the language itself, we can emulate rank-N types using traits, as mentioned [here](https://phaazon.net/blog/rank-n-rust).

One of the important components of the GDP technique is the ability to name specific values at the type-level. To do this, we define a `name` function:

```rust
use std::marker::PhantomData;

pub trait NameFn<Input> {
    type Output;

    fn call<Name>(self, input: Named<Input, Name>) -> Self::Output;
}

/// A named value where the name is opaque
pub struct Named<A, N> {
    value: A,
    name: PhantomData<N>,
}

impl<A, N> Named<A, N> {
    /// Unnames a named value and returns that value
    pub fn unname(self) -> A {
        self.value
    }

    /// Unnames a named value and returns a reference to that value
    pub fn unname_ref(&self) -> &A {
        &self.value
    }
}

pub fn name<In, F: NameFn<In>>(input: In, f: F) -> {
    f.call(Named {
	    value: input,
		name: PhantomData::<()>
	})
}
```

Implementors of `NameFn` can be passed as callbacks to other functions. What's important here is that we have a type parameter that is scoped to the callback and not to the `name` method. That way, API users cannot choose the type-level name for the value. It will be completely opaque to them. The unname methods are for extracting the value from a named value.

So what does naming specific values help us achieve? One example that the paper gives is sorting and merging two lists into one. We can specify that the merge function uses the same comparator as the one used to sort the two lists. In Rust, that looks like this:

```rust
mod gdp_merge_by {
    use std::marker::PhantomData;
    use std::cmp::Ordering;
    use super::gdp::Named;

    /// A vector sorted by a comparator with name N
    pub struct SortedBy<T, N> {
        vec: Vec<T>,
        _pd: PhantomData<N>
    }

    impl<T, N> SortedBy<T, N> {
        pub fn vec(self) -> Vec<T> {
            self.vec
        }
    }

    /// Takes `vec` and returns a named SortedBy<Vec<u32>, N>
    /// sorted by named comparator `compare`
    pub fn sort_by<T, N, F: Fn(&T, &T) -> Ordering>(
        mut vec: Vec<T>,
        compare: &Named<F, N>
    ) -> SortedBy<T, N> {
        vec.sort_by(compare.unname_ref());
        SortedBy {
            vec,
            _pd: PhantomData
        }
    }

    /// Merges `sorted1` and `sorted2` into a single vector
    /// sorted by the same comparator (`compare`) as `sorted1` and `sorted2`
    pub fn merge_by<T, N, F: Fn(&T, &T) -> Ordering>(
        sorted1: SortedBy<T, N>,
        mut sorted2: SortedBy<T, N>,
        compare: &Named<F, N>
    ) -> SortedBy<T, N> {
        let mut v = sorted1.vec;
        v.append(&mut sorted2.vec);
        v.sort_by(compare.unname_ref());
        SortedBy {
            vec: v,
            _pd: PhantomData
        }
    }
}

use std::marker::PhantomData;
use std::cmp::Ordering;
use gdp::{name, Named, NameFn};
use gdp_merge_by::*;

struct Comp {
    v1: Vec<u32>,
    v2: Vec<u32>
}

impl NameFn for Comp {
    type A = fn(&u32, &u32) -> Ordering;
    type Output = Vec<u32>;

    fn call_once<N>(self, named: Named<Self::A, N>) -> Self::Output {
        let sorted1 = sort_by(self.v1, &named);
        let sorted2 = sort_by(self.v2, &named);
        merge_by(sorted1, sorted2, &named).vec()
    }
}

/// Read two Vecs of u32s from the user and sort them in ascending order then merge them
/// user input:
/// 1 5 2
/// 2 9 7
/// expect: vec![1, 2, 2, 5, 7, 9]
fn sort_then_merge(v1: Vec<u32>, v2: Vec<u32>) -> Vec<u32> {
    let f: fn(&u32, &u32) -> Ordering = |a, b| a.cmp(b);
    name(f, Comp { v1, v2 })
}
```

We can generalize the GDP technique as well by adding the ability to attach proofs to values. We can then add type-level proof combinators to allows us to create more complicated proofs. Here is what that looks like in Rust:

```rust
use std::marker::PhantomData;

/// A proof that can be passed to a function to prove that a predicate has been satisfied.
///
/// Users should not be allowed to construct proofs directly. Library authors should
/// ensure that their API provides the correct proofs for their library. `T` is a token
/// type that library author can attach to proof values to ensure that the proofs came
/// from their library.
pub struct Proof<P, T>(pub(crate) PhantomData<(P, T)>);

/// A value with a proof attached
pub struct SuchThat<A, P> {
    value: A,
    _pd: PhantomData<P>,
}

impl<A, P> SuchThat<A, P> {
    /// Extracts the value from a proof-attached value
    pub fn value(self) -> A {
        self.value
    }

    /// Returns a reference to the value of a proof-attached value
    pub fn value_ref(&self) -> &A {
        &self.value
    }
}

impl<A, N, P> SuchThat<Named<A, N>, P> {
    /// Extract the value from a proof-attached named value
    pub fn extract(self) -> A {
        self.value().unname()
    }

    /// Returns a reference to the value of a proof-attached named value
    pub fn extract_ref(&self) -> &A {
        self.value_ref().unname_ref()
    }
}

/// Attaches a proof to a value
pub fn with_proof<A, P, T>(value: A, _proof: &Proof<P, T>) -> SuchThat<A, P> {
    SuchThat {
        value,
        _pd: PhantomData,
    }
}

/// Type-level boolean value `True`
pub struct True(PhantomData<()>);

/// Type-level boolean value `False`
pub struct False(PhantomData<()>);

/// Type-level logical conjunction
pub struct And<P, Q>(PhantomData<(P, Q)>);

/// Type-level logical disjunction
pub struct Or<P, Q>(PhantomData<(P, Q)>);

/// Type-level logical implication
pub struct Implies<P, Q>(PhantomData<(P, Q)>);

/// Type-level logical negation
pub struct Not<P>(PhantomData<P>);

/// Type-level logical equality
pub struct Equals<P, Q>(PhantomData<(P, Q)>);

/// Introduces a conjunction into a type-level logical proof
pub fn and_intro<P, Q, T>(_p: &Proof<P, T>, _q: &Proof<Q, T>) -> Proof<And<P, Q>, T> {
    Proof(PhantomData)
}

/// Extracts the left conjunct from a type-level logical conjunction
pub fn and_elim_l<P, Q, T>(_and: &Proof<And<P, Q>, T>) -> Proof<P, T> {
    Proof(PhantomData)
}

/// Extracts the right conjunct from a type-level logical conjunction
pub fn and_elim_r<P, Q, T>(_and: &Proof<And<P, Q>, T>) -> Proof<Q, T> {
    Proof(PhantomData)
}

/// Introduces a disjunction into a type-level logical proof, given a left disjunct
pub fn or_intro_l<P, Q, T>(_p: &Proof<P, T>) -> Proof<Or<P, Q>, T> {
    Proof(PhantomData)
}

/// Introduces a disjunction into a type-level logical proof, given a left disjunct
pub fn or_intro_r<P, Q, T>(_q: &Proof<Q, T>) -> Proof<Or<P, Q>, T> {
    Proof(PhantomData)
}

/// Eliminates a type-level logical disjunction (proof by cases)
pub fn elim_or<P, Q, R, T>(
    _p_to_r: fn(Proof<P, T>) -> Proof<R, T>,
    _q_to_r: fn(Proof<Q, T>) -> Proof<R, T>,
    _or: &Proof<Or<P, Q>, T>,
) -> Proof<R, T> {
    Proof(PhantomData)
}

/// Introduces an implication into a type-level logical proof
pub fn implies_intro<P, Q, T>(_f: fn(Proof<P, T>) -> Proof<Q, T>) -> Proof<Implies<P, Q>, T> {
    Proof(PhantomData)
}

/// Eliminates an implication from a type-level logical proof
pub fn implies_elim<P, Q, T>(_implies: &Proof<Implies<P, Q>, T>, _p: &Proof<P, T>) -> Proof<Q, T> {
    Proof(PhantomData)
}

pub fn not_intro<P, T>(_f: fn(Proof<P, T>) -> Proof<False, T>) -> Proof<Not<P>, T> {
    Proof(PhantomData)
}

pub fn contradicts<P, T>(_p: &Proof<P, T>, _not_p: &Proof<Not<P>, T>) -> Proof<False, T> {
    Proof(PhantomData)
}

pub fn absurd<P, T>(_false: &Proof<False, T>) -> Proof<P, T> {
    Proof(PhantomData)
}

pub fn refl<X, T>() -> Proof<Equals<X, X>, T> {
    Proof(PhantomData)
}

/// Creates a proof of a given type.
///
/// This function requires a token type `T` to prevent users
/// from using it to create arbitrary proofs.
pub fn axiom<P, T>(_token: T) -> Proof<P, T> {
    Proof(PhantomData)
}
```

That's a lot to absorb, so let's break it down. Everything from the top down to `with_proof` is for attaching a proof to or extracting a proof from a value. The rest of the code defines the type-level booleans and proof combinators. The `axiom` method is used to create arbitrary proofs, which should not be called by API users. In this case, I modified the definition a little so it's a bit different from the original paper. Here, I tried to make it so that only library authors could call axiom by forcing callers to pass some kind of token that they can construct. In Haskell, this isn't enforced because there are many ways to break the type system anyway and the API is only meant to protect against programmer errors, not malice. However, Rust has its own definition of safety enforced by its `unsafe` keyword, so I tried to make sure this could allow users to write code that calls `unsafe` code without leaking `unsafe` into all of the caller code. Of course, Rust's type system isn't completely sound due to some compiler bugs, so maybe this isn't all that helpful, but this is all experimental anyway. I never really verified the soundness of this approach, I admit.

Here is an example of how to use this API:

```rust
pub mod gdp_vec {
    use super::gdp::*;
    use std::marker::PhantomData;

    pub struct VecPrf(PhantomData<()>);

    /// The predicate "HasElemAt(Xs, Index)" which is true when there is an element at Index in Xs
    pub struct HasElemAt<Xs, Index> {
        _pd: PhantomData<(Xs, Index)>,
    }

    /// Name for index
    pub struct Index<Xs> {
        _pd: PhantomData<Xs>,
    }

    /// Attaches a name to `index`
    pub fn name_index<T, Xs>(index: usize, _v: &gdp!(Vec<T>, named Xs)) -> gdp!(usize, named Index<Xs>) {
        lib_name(index, Index { _pd: PhantomData })
    }

    /// Returns a proof of whether or not an element at the given index can be found in v
    pub fn elem_at_exists<T, Xs>(
        index: &gdp!(usize, named Index<Xs>),
        v: &gdp!(Vec<T>, named Xs),
    ) -> Option<Proof<HasElemAt<Xs, Index<Xs>>, VecPrf>> {
        if *index.unname_ref() >= v.unname_ref().len() {
            None
        } else {
            Some(axiom(VecPrf(PhantomData)))
        }
    }

    pub fn get<'a, 'b, Xs, T>(
        index: &'a gdp!(usize, named Index<Xs>),
        v: &'b gdp!(Vec<T>, named Xs where HasElemAt<Xs, Index<Xs>>),
    ) -> &'b T {
        &v.extract_ref()[*index.unname_ref()]
    }
}

use crate::gdp::*;
use crate::gdp_vec::*;

struct VecFn;

impl NameFn for VecFn {
    type Input = Vec<u32>;
    type Output = ();

    fn call<Xs>(self, named_vec: Named<Self::Input, Xs>) -> Self::Output {
        let named_index = name_index(1, &named_vec);
        let proof = elem_at_exists(&named_index, &named_vec)
            .expect(&format!("No element at index: {}", named_index.unname_ref().to_string()));
        let vec_with_proof = with_proof(named_vec, &proof);
        let four = get(&named_index, &vec_with_proof);
        println!("{}", four);
    }
}

fn main() {
    let vec: Vec<u32> = vec![1, 4, 7];
    name(vec, VecFn);
}
```

Here, I have created an API where callers needs to prove that an element exists at an index before they can index into a vector. This isn't the typical way to define such an API (see Rust's array type), but I think it gets the point across. Users must check if the vector has an element at an index, which returns an `Option` potentially containing proof of that element existing at the desired index. This proof can then be attached to the named vector, which allows `get` to be called. Now the user does not have to deal with a `Some` value after calling `get`, since they already proved that there is a value at the given index. This properly allows the user to express what they want to the compiler, which better reflects their state of knowledge. Of course, the user won't always be able to prove that an element exists at a desired index, but `Vec` already has its usual API that returns `Option` values in that case.

# The Catch

Unfortunately, this technique is not very ergonomic in Rust. This is partially due to the fact that Rust does not support defining infix type operators. However, even if Rust did support them, we would still have ergonomics issues with rank-N types, since we have to emulate them in an unwieldy fashion. Also, many people dislike the kinds of errors produced when using type-level programming, as they can be quite difficult to read.

# Is there a better solution?

Recently, I have been reading about the Idris programming language and its dependent types. Essentially, dependent types are types that can depend on values, which means that types are first-class. They can be passed into functions and stored in variables, just like values. Thus, type parameters and regular parameters are unified. What the GDP technique enables is similar to what dependent types allow, but dependent types would give us much better ergonomics and none of the hard to read type-level errors. The team working on the Rust language has apparently considered this in the past, but deemed it too difficult to implement dependent types. However, Rust's array type constructor is already parameterized by a value (array length), so dependent typing already has a bit of a foothold in the language.

One of the items on the 2019 roadmap for Rust was `const` generics, which would allow the usage of constant values where generic type parameters are. While the initial implementation would not allow them to be used in expressions, it would certainly open the door to that as a possibility, which would bring us much closer to dependent types. Sadly, it seems that progress this year was fairly slow and not much of the roadmap was completed, including `const` generics. It is quite unlikely that we will see this feature stabilize with expression support in the near future, so GDP and other type-level techniques will have to do for now.