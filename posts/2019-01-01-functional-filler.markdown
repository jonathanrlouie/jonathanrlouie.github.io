---
layout: post
title:  A Functional Facelift for the Item Filler
date:   2019-01-01 03:00:00 -0700
categories: Rust, functional programming, mini-rando
---

Earlier in December, I attended John A. De Goes\' Functional Scala workshop. Although not all of the concepts I learned from the workshop can be used in Rust, I did learn a few techniques that can be. This lead me to try and make some changes in mini-rando to make it a bit more typesafe. I know this sort of design philosophy stuff can really rile some people up, so I just want to be up front and say that I understand why one might not want to write their code in this style, and that\'s perfectly okay. I\'m just trying to give some insight into how certain people like to write their code \-\- let\'s keep things friendly, yo.

For this post, I want to focus solely on the item filler. First off, here is what the original code I posted on this blog looked like:

```rust
pub fn fill_locations(
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    other_items: Vec<LabelledItem>
) -> Vec<FilledLocation> {
    debug_assert!(locations.len() == prog_items.len() + other_items.len());

    let ProgressionFillerResult(mut filled_locs, remaining_locs): ProgressionFillerResult =
        progression_filler(prog_items, locations);

    filled_locs.append(&mut fast_filler(other_items, remaining_locs));
    filled_locs
}

fn progression_filler(
    mut prog_items: Vec<LabelledItem>,
    mut locations: Vec<Location>
) -> ProgressionFillerResult {
    let mut remaining_locations: LinkedHashSet<LocId> =
        LinkedHashSet::from_iter(locations
            .iter()
            .map(|ref loc| loc.0));

    let mut filled_locations: Vec<FilledLocation> = vec![];

    let item_count = prog_items.len();

    for _ in 0..item_count {
        let option_item = prog_items.pop();
        locations = locations
            .into_iter()
            .filter(|&Location(_, ref is_accessible)| is_accessible.0(&prog_items))
            .collect();
        let option_location = locations.pop();
        if let (Some(item), Some(chosen_location)) = (option_item, option_location) {
            filled_locations.push(FilledLocation(item, chosen_location.0));
            remaining_locations.remove(&chosen_location.0);
        } else if option_item.is_none() {
            panic!("Out of items");
        } else {
            panic!("Out of locations");
        }
    }

    ProgressionFillerResult(filled_locations, remaining_locations)
}

fn fast_filler(items: Vec<LabelledItem>, locations: LinkedHashSet<LocId>) -> Vec<FilledLocation> {
    debug_assert!(items.len() == locations.len());
    items
        .into_iter()
        .zip(locations)
        .map(|(item, loc)| FilledLocation(item, loc))
        .collect()
}
```

If we want to make this code more typesafe, the first issue that stands out is the presence of debug asserts and panics. In fact, panicking isn\'t even idiomatic in Rust, as errors should generally be returned as values using the `Result` or `Option` types. Our goal is to remove the need for run time checks by banning the creation of invalid states to begin with. To do this, we will take advantage of \"smart constructors\" and apply the functional practice of writing total functions.

First, we will eliminate all of the debug asserts. Instead of checking for invalid states in the item filler code, we will be moving the checks into smart constructors. Let\'s look at the first debug assert here:

```rust
pub fn fill_locations(
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    other_items: Vec<LabelledItem>
) -> Vec<FilledLocation> {
    debug_assert!(locations.len() == prog_items.len() + other_items.len());

    let ProgressionFillerResult(mut filled_locs, remaining_locs): ProgressionFillerResult =
        progression_filler(prog_items, locations);

    filled_locs.append(&mut fast_filler(other_items, remaining_locs));
    filled_locs
}
```

This debug assert checks that the sum of the number of progression and other items is equal to the number of locations. In order to remove this debug assert, I decided to create a new product type of the three input parameter types and pass a value of that type into `fill_locations()`. Here is the new product type I created:

```rust
pub mod shuffled {
    use super::{
        LabelledItem,
        Location
    };

    pub struct Shuffled(Vec<Location>, Vec<LabelledItem>, Vec<LabelledItem>);

    impl Shuffled {
        pub fn new(locations: Vec<Location>, prog_items: Vec<LabelledItem>, junk_items: Vec<LabelledItem>) -> Option<Self> {
            if locations.len() == prog_items.len() + junk_items.len() {
                Some(Shuffled(locations, prog_items, junk_items))
            } else {
                None
            }
        }

        pub fn get(self) -> (Vec<Location>, Vec<LabelledItem>, Vec<LabelledItem>) {
            (self.0, self.1, self.2)
        }
    }
}
```

As you can see, the `Shuffled` tuple struct that I defined here will hold the three arguments that will be passed into `fill_locations()`. I could have opted for a regular struct instead of the tuple struct, but I feel that the difference here is fairly small. Note that in this implementation, I made only the `Shuffled` type public, not the actual arguments. Thus, the code outside of this module is unable to construct a `Shuffled` through the default constructor syntax `Shuffled(a, b, c)`. It is important to note that this default constructor is accessible from anywhere within the `shuffled` module, meaning that in order to hide the constructor from the outside world, we must define `Shuffled` inside this separate `shuffled` module. The actual smart constructor itself simply returns a value of type `Option<Self>` instead of a value of type `Self`, using the original debug assert condition to determine whether a `Some` or a `None` is returned. In contrast with Scala, we cannot specify whether or not a particular field of a struct is immutable or not, since mutability is controlled by the caller. However, we can still ensure that the contents of our struct are never modified. In this case, I created an accessor `get()` to return all of the contents of the struct in a tuple. The key thing to note about this signature is that `get()` moves `self`, meaning that once we return all of this data, the caller has full control over the data and the `Shuffled` struct will be deallocated. Alternatively, I could have defined an accessor that only took `&self` and then returned copies of the internal data, but this was sufficient for my needs.

Alright! We now have a smart constructor defined, so we can eliminate that debug assert! Let\'s see what that looks like:

```rust
pub fn shuffle_and_fill(
    rng: &mut StdRng,
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    junk_items: Vec<LabelledItem>
) -> Vec<FilledLocation> {
    let shuffled = shuffle_world(rng, locations, prog_items, junk_items);
    fill_locations(shuffled)
}

pub fn shuffle_world(
    rng: &mut StdRng,
    mut locations: Vec<Location>,
    mut prog_items: Vec<LabelledItem>,
    mut junk_items: Vec<LabelledItem>
) -> Shuffled {
    rng.shuffle(&mut prog_items);
    rng.shuffle(&mut locations);
    rng.shuffle(&mut junk_items);
    Shuffled::new(locations, prog_items, junk_items)
}

pub fn fill_locations(
    shuffled: Shuffled
) -> Vec<FilledLocation> {
	let (locations, prog_items, other_items) = shuffled.get();

    let ProgressionFillerResult(mut filled_locs, remaining_locs): ProgressionFillerResult =
        progression_filler(prog_items, locations);

    filled_locs.append(&mut fast_filler(other_items, remaining_locs));
    filled_locs
}
```

I\'ve included the caller of our smart constructor here so you can see the full extent of the changes. In this case, we have a function `shuffle_world()` which will shuffle all of the locations and items using the passed-in RNG. This function calls our `new()` smart constructor, returns the result, and allows `shuffle_and_fill()` to pass the constructed `Shuffled` directly to `fill_locations()`. In `fill_locations()`, we now just call `get()` to retrieve the contents of `shuffled` and use pattern matching syntax to name the elements of the returned tuple. But wait! We now have a new problem! This code won\'t type check! As it turns out, at least according to the statically typed FP people, this is actually a good thing. We forgot to handle the `Option` that our smart constructor now returns, which is causing the compiler to complain. It is important to note that how we handled the invalid state here was not necessarily a problem, but the fact that we were able to construct invalid state in the first place was. Now, as long as we don\'t change our data model, we will be unable to construct an invalid state. On a side note, this goes hand-in-hand with the [Open-closed principle](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle) of [SOLID](https://en.wikipedia.org/wiki/SOLID) design, where we want to avoid making modifications to our data model. Perhaps SOLID isn\'t necessarily specific to OO after all :)

Okay, so now we have to actually handle the returned `Option`. But how should we do so? In general, it is good practice not to make decisions on behalf of the caller so as not to assume anything about the caller\'s intentions. Thus, the simplest solution is to be as lazy as possible. We\'ll just change our function signatures to return `Option` themselves and let the caller decide how the `Option` is actually handled. Here\'s what our code looks like now:

```rust
pub fn shuffle_and_fill(
    rng: &mut StdRng,
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    junk_items: Vec<LabelledItem>
) -> Option<Vec<FilledLocation>> {
    let shuffled = shuffle_world(rng, locations, prog_items, junk_items);
    fill_locations(shuffled)
}

pub fn shuffle_world(
    rng: &mut StdRng,
    mut locations: Vec<Location>,
    mut prog_items: Vec<LabelledItem>,
    mut junk_items: Vec<LabelledItem>
) -> Option<Shuffled> {
    rng.shuffle(&mut prog_items);
    rng.shuffle(&mut locations);
    rng.shuffle(&mut junk_items);
    Shuffled::new(locations, prog_items, junk_items)
}
```

We\'re a bit closer now, but this code still doesn\'t type check. `shuffle_and_fill()` is not returning an option at all, so we need to adjust our code. Thanks to the functor properties of `Option`, we can simply call `map()` to resolve this issue. Let\'s see how that looks:

```rust
pub fn shuffle_and_fill(
    rng: &mut StdRng,
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    junk_items: Vec<LabelledItem>
) -> Option<Vec<FilledLocation>> {
    let shuffled = shuffle_world(rng, locations, prog_items, junk_items);
    shuffled.map(fill_locations)
}
```

This code will now return a `None` in the case that `shuffled` is `None` and a `Some` of the result of `fill_locations()` otherwise. It\'s a pretty simple change. By applying this same smart constructor pattern to the other debug assert, we can remove that one too, like so:

```rust
pub mod fast_filler_args {
    use linked_hash_set::LinkedHashSet;
    use super::super::{
        item::LabelledItem,
        location::LocId
    };

    pub struct FastFillerArgs(Vec<LabelledItem>, LinkedHashSet<LocId>);

    impl FastFillerArgs {
        pub fn new(items: Vec<LabelledItem>, locations: LinkedHashSet<LocId>) -> Option<Self> {
            if items.len() == locations.len() {
                Some(FastFillerArgs(items, locations))
            } else {
                None
            }
        }

        pub fn get(self) -> (Vec<LabelledItem>, LinkedHashSet<LocId>) {
            (self.0, self.1)
        }
    }
}

pub fn fill_locations(
    shuffled: Shuffled
) -> Option<Vec<FilledLocation>> {
	let (locations, prog_items, other_items) = shuffled.get();

    let ProgressionFillerResult(mut filled_locs, remaining_locs): ProgressionFillerResult =
        progression_filler(prog_items, locations);

    let option_fast_filler_args = FastFillerArgs::new(other_items, remaining_locs);

    if let Some(fast_filler_args) = option_fast_filler_args {
        filled_locs.append(&mut fast_filler(fast_filler_args));
        Some(filled_locs)
    } else {
        None
    }
}

fn fast_filler(args: FastFillerArgs) -> Vec<FilledLocation> {
    let (items, locations) = args.get();
    items
        .into_iter()
        .zip(locations)
        .map(|(item, loc)| FilledLocation(item, loc))
        .collect()
}
```

Now, `fill_locations()` must return `Option<Vec<FilledLocation>>` instead of `Vec<FilledLocation>`. We also need to make some minor adjustments here to make sure that we return the `Option` produced by `FastFillerArgs::new()`. I opted for an `if let` expression rather than a `map()` so I could be explicit about the side-effect produced here. However, these changes are not enough on their own. If we were to leave the code in its current state, it would fail to type check! This is because `shuffle_and_fill()` is calling `shuffled.map(fill_locations)`, which would produce an `Option<Option<Vec<FilledLocation>>>` and not an `Option<Vec<FilledLocation>>`. Luckily, `Option` is also a monad, so we can take advantage of its `flatMap()` function, which is called `and_then()` in Rust:

```rust
pub fn shuffle_and_fill(
    rng: &mut StdRng,
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    junk_items: Vec<LabelledItem>
) -> Option<Vec<FilledLocation>> {
    let shuffled = shuffle_world(rng, locations, prog_items, junk_items);
    shuffled.and_then(fill_locations)
}
```

Hooray! Everything type checks again! That was relatively painless, wasn\'t it? Well, that only addresses our debug asserts. Let\'s switch our focus over to those two panics in the progression filler algorithm. Here is the code in question:

```rust
fn progression_filler(
    mut prog_items: Vec<LabelledItem>,
    mut locations: Vec<Location>
) -> ProgressionFillerResult {
    let mut remaining_locations: LinkedHashSet<LocId> =
        LinkedHashSet::from_iter(locations
            .iter()
            .map(|ref loc| loc.0));

    let mut filled_locations: Vec<FilledLocation> = vec![];

    let item_count = prog_items.len();

    for _ in 0..item_count {
        let option_item = prog_items.pop();
        locations = locations
            .into_iter()
            .filter(|&Location(_, ref is_accessible)| is_accessible.0(&prog_items))
            .collect();
        let option_location = locations.pop();
        if let (Some(item), Some(chosen_location)) = (option_item, option_location) {
            filled_locations.push(FilledLocation(item, chosen_location.0));
            remaining_locations.remove(&chosen_location.0);
        } else if option_item.is_none() {
            panic!("Out of items");
        } else {
            panic!("Out of locations");
        }
    }

    ProgressionFillerResult(filled_locations, remaining_locations)
}
```

What can we do about these panics? We\'re already getting `Option`s here, so we are already handling the `None` cases at compile time, but we\'re panicking instead of returning a value. This breaks functional totality and also totally crashes our game! Yuck! To fix this, we can simply have the progression filler function return an `Option`. However, we then have another problem. We somehow need to ergonomically return a `None` from inside of our imperative for-each loop in the case that one of the two vectors is empty. Luckily, Rust has just the tool for this problem \-\- the `?` operator. In Rust, the `?` operator behaves very differently from other languages, where it is used as a ternary operator. Here, `?` is actually a unary postfix operator that simply makes the function return early if its operand is `None`. The result returned by early returning through `?` will be a `None`. In a way, this is almost like throwing an exception, except throwing an exception does not return a value, whereas `?` returns a value. Interestingly, this `?` operator allows Rust to emulate monad comprehensions for specific monads. Consider the following Scala code:

```scala
def foo(): Option[Int] = Some(1)

def bar(): Option[Int] = Some(2)

def baz(a: Int, b: Int): Option[Int] = Some(a + b)

val result = for {
  a <- foo()
  b <- bar()
  c <- baz(a, b)
} yield c * 2

println(result)
```

Here, we have 3 functions returning `Option[Int]` and we want to call `baz()` on the integers returned by `foo()` and `bar()` if they both return a `Some`. Then, if the result of `baz()` is a `Some`, we multiply the contained result by 2 and store the resulting value in `result`. For those unaware of how Scala\'s monad/for comprehensions work, here is what that desugars to:

```scala
val result = {
	foo.flatMap(a => 
		bar.flatMap(b =>
			baz(a, b).map(c => c * 2)))
}
```

As you can see, it\'s just a bunch of `flatMap()`s and a final `map()`. More importantly, however, we see what problem the monad/for comprehension solves. This desugared code suffers from the so-called \"callback hell\" problem. So how does this relate to Rust\'s `?` operator? Well, we can rewrite this as the following Rust code:

```rust
fn foo() -> Option<i32> { Some(1) }

fn bar() -> Option<i32> { Some(2) }

fn baz(a: i32, b: i32) -> Option<i32> { Some(a + b) }

fn for_comp() -> Option<i32> {
    let a = foo()?;
    let b = bar()?;
    baz(a, b).map(|c| c * 2)
}

fn main() {
    let result = for_comp();
    
    println!("{:?}", result);
}
```

As you can see, this translation looks very similar to the equivalent Scala code. Here, the `?` operator is used to replace our calls to `flatMap()`. Thus, `?` can also be used to help us when we want to use a monad comprehension for `Option`s. It is worth noting that Rust does not support monad comprehensions and uses special syntax like `?` for specific monads because Rust does not currently support HKTs and cannot really express a monad abstraction (barring some trickery that some crates have done).

With all that out of the way, let\'s try using this `?` operator:

```rust
fn progression_filler(
    mut prog_items: Vec<LabelledItem>,
    mut locations: Vec<Location>
) -> Option<ProgressionFillerResult> {
    let mut remaining_locations: LinkedHashSet<LocId> =
        LinkedHashSet::from_iter(locations
            .iter()
            .map(|ref loc| loc.0));

    let mut filled_locations: Vec<FilledLocation> = vec![];

    let item_count = prog_items.len();

    for _ in 0..item_count {
        let item = prog_items.pop()?;
        locations = locations
            .into_iter()
            .filter(|&Location(_, ref is_accessible)| is_accessible.0(&prog_items))
            .collect();
        let location = locations.pop()?;
        filled_locations.push(FilledLocation(item, location.0));
        remaining_locations.remove(&location.0);
    }

    Some(ProgressionFillerResult(filled_locations, remaining_locations))
}
```

Nice! Our function now successfully returns the `Option` we wanted it to with very few changes to the code. In fact, it looks quite a bit cleaner now, too. Of course, we\'re not done yet, as we need to adjust the caller of this function now to account for the new type signature. Here is our new `fill_locations()`:

```rust
fn fill_locations(
    shuffled: Shuffled
) -> Option<Vec<FilledLocation>> {
    let (locations, prog_items, other_items) = shuffled.get();

    let ProgressionFillerResult(mut filled_locs, remaining_locs): ProgressionFillerResult =
        progression_filler(prog_items, locations)?;

    let option_fast_filler_args = FastFillerArgs::new(other_items, remaining_locs);

    if let Some(fast_filler_args) = option_fast_filler_args {
        filled_locs.append(&mut fast_filler(fast_filler_args));
        Some(filled_locs)
    } else {
        None
    }
}
```

Can you spot the difference? Since we decided to be lazy earlier and just have `fill_locations()` return an `Option`, we can use the `?` operator again. We can also use `?` to remove the `and_then()` call we used in `shuffle_and_fill()`:

```rust
pub fn shuffle_and_fill(
    rng: &mut StdRng,
    locations: Vec<Location>,
    prog_items: Vec<LabelledItem>,
    junk_items: Vec<LabelledItem>
) -> Option<Vec<FilledLocation>> {
    let shuffled = shuffle_world(rng, locations, prog_items, junk_items)?;
    fill_locations(shuffled)
}
```

Cool! At this point, we\'ve now removed all of the panics and debug asserts. 


# Closing Thoughts

What is interesting about this is how painless it all was. Sure, creating the submodules with the smart constructors was a bit more time consuming than it would be in Scala, but the actual code changes were fairly minimal. A lot of that can be attributed to Rust\'s `?` syntax, which I really do appreciate. I do want to note that there are additional changes that can be made here, such as making the functions polymorphic. Polymorphic functions restrict the number of ways you can implement a function, reducing the number of wrong implementations you can make while also giving callers more flexibility in terms of what arguments they can pass to the function. In Rust, this is fairly easy, since its generics behave like Scala\'s for the most part. However, there are times where the borrow checker can make this a little bit more difficult. Another change I am contemplating here is changing some of the `Option`s into `Result`s. This would allow me to be more specific about the errors that occur in the filler algorithm, instead of just returning `None`. I also do realize that Amethyst\'s ECS design actively works against the programming style presented in this post. However, there are still some pockets of initialization code where I think it won\'t harm performance too much to write code this way. Plus, the game is meant to be pretty small, so I think it can afford to take more performance hits than a lot of other games. I consider a lot of the work I\'m doing on this project as experimental, so I\'m mostly just trying this out to test my own knowledge and see how well it all pans out.

In addition to my thoughts above, I wanted to touch on what value there is in writing code in this style. By taking this approach, we turn our run time problems into compile time problems, which reduces the risk of users running into run time errors and crashes. This is very much the design philosophy that Rust and many statically typed functional languages try to adhere to. While this does appeal to certain kinds of people, it does introduce some amount of friction between the programmer and the compiler, which may not be so desirable in certain projects. In particular, this trade-off of more friction for fewer bugs may not be so desirable for game development, where it is more acceptable for bugs to be present in the final product and deadlines are tight. That being said, I still think that there may be some value in using this kind of approach in game development, especially with the rise of eSports and multi-million dollar prize pools for gaming tournaments. It would be pretty tragic to lose a game with millions of dollars on the line due to a bug that could have been prevented had the game been written in a more typesafe way.
