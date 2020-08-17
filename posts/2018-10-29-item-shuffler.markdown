---
layout: post
title:  Item Shuffler Algorithm (Written in Rust)
date:   2018-10-29 22:37:00 -0700
categories: randomizer, Rust
---

It\'s the end of the month again, which means it\'s time for another update! With my [new channel](https://www.youtube.com/channel/UCjQgvE-k654RiRCLXa7JQNw), I\'ve been making steady progress working on Mini-rando. As a result, this post is about the item shuffler algorithm that I implemented for the game. The algorithm itself is nothing special. It essentially follows the algorithm described in [this document](https://www.dropbox.com/s/vh5voea4s0e3cha/how_to_read_the_logic.pdf?dl=0). However, I did want to try my hand at writing a concrete implementation of this algorithm in Rust to give myself some more practice with the language, as well as show how one might write a concrete implementation of an item randomizer. I do know that there are plenty of open source implementations for item randomizers out there already, but hey, another more detailed example couldn\'t hurt, right?

Before we start, I want to give a brief overview of how this particular implementation of an item randomizer works. For this implementation, there are three major steps. The first is to randomly shuffle the item locations and items so that we do not fill item locations with the same items in every seed. The second is to run an \"assumed filler\" algorithm to populate item locations with progression items. Here, we define a progression item as any item that the player may need in order to reach another item location. The last step is to run a \"fast filler\" algorithm, which will populate the rest of the item locations with non-progression items. Optionally, this fast filler phase can be customized to populate locations with \"nice to have\" items before the less helpful items.

First off, we\'re going to start with the \"assumed filler\", as outlined in aforementioned document. Before we can dive directly into the algorithm, however, we first need some data definitions:

```rust
#[derive(Copy, Clone, Debug, PartialEq)]
pub enum Item {
    Item0,
    Item1,
    Item2,
    Item3
}

#[derive(Copy, Clone, Debug, PartialEq)]
pub enum LabelledItem {
    Progression(Item),
    Nice(Item),
    Junk(Item)
}

pub struct IsAccessible(pub Box<Fn(&[LabelledItem]) -> bool>);

#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub struct LocId(pub u64);

impl fmt::Display for LocId {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

pub struct Location(pub LocId, pub IsAccessible);
```

Here, I define the items as an enum called `Item`. I used the variants `Item0`, `Item1`, `Item2`, and `Item3` because I wanted to use placeholder items while I am trying to come up with actual item names. As an example of how this enum would be used, if we were implementing this algorithm for _A Link to the Past_, we would include the variants \"Hookshot\", \"Fire rod\" and \"20 Rupees\". The struct `LabelledItem` is a way of categorizing items into different bins. This categorization can be used to determine how certain items are shuffled and help us make sure we don\'t mix up our progression items with our non-progression items. Locations that items will appear in are characterized by the `Location` struct, which consists of a `LocId` and `IsAccessible`. Using `LocId` to wrap a `u64` is just an example of using the newtype pattern. The `LocId` is, as you might have guessed, simply a unique identifier for each location. Implementing `fmt::Display` for `LocId` isn\'t particularly important, but it allows the `LocId` to be printed to console. I also implemented some other boilerplate traits for `LocId` with the derive attribute. Lastly, `IsAccessible` is another example of the newtype pattern. It simply wraps a boxed closure that takes a slice of `LabelledItem`s as an argument and produces a boolean value. The closure is responsible for determining whether or not the location is accessible to the player, based on the given list of items that the player is assumed to have access to. The closure is boxed so that `IsAccessible` structs have a fixed size, which allows `Location` structs to be stored in a vector. This also allows us to define separate sets of locations for different stages/maps in the game without needing to create a large enum and a massive match expression to go with it.

In addition, there are a couple of additional data definitions that I defined in my filler module:

```rust
#[derive(Debug, PartialEq)]
pub struct FilledLocation(pub LabelledItem, pub LocId);

// Contains filled locations and remaining empty locations
struct ProgressionFillerResult(Vec<FilledLocation>, LinkedHashSet<LocId>);
```

A `FilledLocation` is a pairing of a `LabelledItem` with a `LocId`. We will use these to store the final results of our filler algorithm. As the comment here suggests, a `ProgressionFillerResult` contains a vector of filled locations and a linked hash map of the remaining empty locations after we have run the assumed filler algorithm. This result is required so that the fast filler knows which locations are still valid when it populates the remaining locations.

Without further ado, here is code for the assumed filler:

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

This code is roughly equivalent to the following pseudo code:

```
create a clone collection of remaining locations from the given list of potential item locations
create an empty collection of filled item locations
count the given progression items
repeat the following the same number of times as the number of progression items:
	remove and retrieve the first progression item from the list of progression items
	filter out the potential item locations that are not accessible given the remaining progression items in the list of progression items
	remove and retrieve the first location from the remaining potential item locations
	add the retrieved progression item and location to the collection of filled item locations
	remove the retrieved location from the cloned collection of remaining locations
return the filled item locations with the clone collection of remaining locations
```

You may notice that no RNG is involved in this algorithm. This is because we can perform the shuffling independently of the item filling. In fact, that is the step we perform prior to executing this algorithm. The lists of progression items and locations are pre-shuffled, which allows us to simply pop the first element off of each collection as we\'re filling in the item locations. I also neglected the `if` condition, as well as the two panics, since those are just for handling failures should we try to remove an item or location from an empty collection. In practice, this will never happen, so these cases just panic to let us know that we have made an error when passing in the arguments. Arguably, I should return a Result or Option here instead, but for now, I\'m sticking to panics. Lastly, the reason why I define the remaining locations as a `LinkedHashSet` is because it makes the remove operation faster while also preserving the shuffled order of locations.

Now, for the fast filler:

```rust
fn fast_filler(items: Vec<LabelledItem>, locations: LinkedHashSet<LocId>) -> Vec<FilledLocation> {
    debug_assert!(items.len() == locations.len());
    items
        .into_iter()
        .zip(locations)
        .map(|(item, loc)| FilledLocation(item, loc))
        .collect()
}
```

This is a fairly trivial implementation. Since we have the same number of items and locations, we can just pair up the items and locations to produce a vector of filled locations. It is perfectly safe to do this since we do not have any items with restrictions on where they can be placed. The debug assert isn\'t necessary, but I threw it in to catch any mistakes I may make while I am working on a debug build.

Finally, we put the two algorithms together:

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

This code is also fairly self-explanatory. It simply takes the pre-shuffled vectors of the potential item locations, the progression items, and the non-progression items and passes them along to the assumed filler. It then pipes the output of the assumed filler into the input of the fast filler before returning the final vector of filled item locations. Here is an example of how one might call this function:

```rust
let mut locations: Vec<Location> = vec![
    Location(LocId(0), IsAccessible(Box::new(
        |items| has_item(items, LabelledItem::Progression(Item::Item0))))),
    Location(LocId(1), IsAccessible(Box::new(|items| {
        has_item(items, LabelledItem::Progression(Item::Item0)) &&
            has_item(items, LabelledItem::Progression(Item::Item1))
    }))),
    Location(LocId(2), IsAccessible(Box::new(|_| true))),
    Location(LocId(3), IsAccessible(Box::new(|_| true))),
    Location(LocId(4), IsAccessible(Box::new(|_| true))),
    Location(LocId(5), IsAccessible(Box::new(|_| true)))
];

let mut prog_items: Vec<LabelledItem> = vec![
    LabelledItem::Progression(Item::Item0),
    LabelledItem::Progression(Item::Item1),
    LabelledItem::Progression(Item::Item2)
];

let mut junk_items: Vec<LabelledItem> = vec![
    LabelledItem::Junk(Item::Item3),
    LabelledItem::Junk(Item::Item3),
    LabelledItem::Junk(Item::Item3)
];

let mut rng: StdRng = StdRng::from_seed([0u8; 32]);

rng.shuffle(&mut prog_items);
rng.shuffle(&mut locations);
rng.shuffle(&mut junk_items);

let filled_locations =
    fill_locations(
        locations,
        prog_items,
        junk_items);
```

In this example, the RNG related structs and methods come from the `rand` crate. Thus, I can simply shuffle the vectors using `rng.shuffle()`. One other thing to note is the usage of `has_item()` when defining the `IsAccessible` closures. `has_item()` is defined as follows:

```rust
pub fn has_item(items: &[LabelledItem], item: LabelledItem) -> bool {
    items.iter().any(|&assumed_item| assumed_item == item)
}
```

All that this function does is check if the given item is in our slice of items that the player is assumed to be able to reach.

And that\'s it! We\'ve now written the algorithm for an item randomizer in Rust! :) While there is probably still a bit more room for improvement, I am quite pleased with how this implementation turned out.