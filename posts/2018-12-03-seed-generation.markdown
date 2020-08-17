---
layout: post
title:  Shareable Seed Generation
date:   2018-12-03 22:00:00 -0700
categories: randomizer, gaming, Rust
---

While working on Mini-rando, I found myself in need of a way to generate random seeds that are shareable with other players. This did not strike me as being a particularly difficult task at first, but the problem ended up being a little more complex than I initially had imagined. It also was not easy finding design documentation on this issue online. As a result, I decided to document how I approached this issue.

The first issue I encountered was deciding on a seed format. Since the intent is for players to input these seeds themselves, I needed to design the seed format such that it made for an acceptable user experience. As a result, my criteria for the format was that the seeds were of a reasonably short length, and could not contain ambiguous characters. I also required the seed format to be complex enough so that there would be a large enough number of unique seeds such that players would not end up playing the same few seeds and becoming bored. Since sharing seeds is a somewhat common practice among randomized games, including a number of roguelikes, I decided to look at a couple of different games to see how they formatted seeds. The first game I looked at was Crypt of the Necrodancer. I noted that the seeded mode took a non-lowercase alphanumeric string of length 10 as an input seed. Likewise, after looking at one of the ALTTP randomizer seeds shared on [r/alttpr](https://www.reddit.com/r/alttpr), I noticed that it used the same seed format. While I do not fully understand the significance of this seed format, I decided to follow along and attempt to do the same, since the format fits my criteria reasonably well.

To generate the seed itself, I decided to start by using the `rand` crate\'s default `thread_rng()` function. Immediately, I noted two issues. The first was that the `thread_rng()` function produced an integer value. This meant that I needed to perform some kind of transformation on the output of `thread_rng()` in order to get a seed in the format I wanted. The second issue was that most seedable RNGs are seeded using integer values or byte arrays, and `rand` is no exception. This meant that I could not possibly hope to pass a seed with alphanumeric format to the RNG as is. In order to preserve the easy-to-share nature of the seeds while still being able to have fairly complex seed values that worked with `rand`, I decided to split the definition of the seed into two parts. One would be the seed\'s user-friendly ID, and the other would be its `rand`-friendly integer representation:

```rust
pub struct SeedId(pub String);

pub struct IntSeed(pub u64);

pub struct Seed {
    pub id: SeedId,
    pub int_seed: IntSeed
}
```

To generate the user-friendly ID, I first looked through the documentation for `rand` to see if there was not already an existing solution to the problem. Though the alphanumeric distribution seemed promising, it included lowercase letters. Thus, I opted to write my own transformation function. Since there are 26 letters in the English alphabet and 10 digits, there are 36 possible values for each character in total. By generating each character as an integer in the range [0, 35], I simply mapped each integer to its corresponding character with the following function:

```rust
fn map_to_id_char(num: u8) -> char {
    debug_assert!(num <= 35);
    match num {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        4 => 'E',
        5 => 'F',
        6 => 'G',
        7 => 'H',
        8 => 'I',
        9 => 'J',
        10 => 'K',
        11 => 'L',
        12 => 'M',
        13 => 'N',
        14 => 'O',
        15 => 'P',
        16 => 'Q',
        17 => 'R',
        18 => 'S',
        19 => 'T',
        20 => 'U',
        21 => 'V',
        22 => 'W',
        23 => 'X',
        24 => 'Y',
        25 => 'Z',
        26 => '0',
        27 => '1',
        28 => '2',
        29 => '3',
        30 => '4',
        31 => '5',
        32 => '6',
        33 => '7',
        34 => '8',
        35 => '9',
        _ => 'A'
    }
}
```

Admittedly, this is not the most elegant solution and the error handling could be improved. However, it gets the job done for now. The actual ID generation code looks something like this:

```rust
use rand::{
    thread_rng, Rng,
    distributions::Uniform
};

const ID_LENGTH: usize = 10;

let range = Uniform::new_inclusive(0, 35);

let id = thread_rng()
    .sample_iter(&range)
    .take(ID_LENGTH)
    .map(|c: u8| map_to_id_char(c))
    .collect::<String>();
```

And that\'s all! It ended up being very simple to implement.

Next, I needed to create the `rand`-friendly integer representation of the seed. This seemed a bit more tricky. I pondered how all these games were taking these 10 character alphanumeric strings and using them as RNG seeds. With a 10 character string where each character can take on one of 36 different values, there are 36<sup>10</sup> different seed values, which is far too many unique values for a pattern matching expression. Thus, after a bit of research, I decided that the best solution was to hash the user-friendly seed ID to get its `u64` representation. Rather than implementing my own hashing algorithm, I decided to take advantage of Rust\'s `std::hash::Hash` and `std::hash::Hasher` traits to do the work for me:

```rust
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

fn hash_seed_id<T: Hash>(id: &T) -> IntSeed {
    let mut hasher = DefaultHasher::new();
    id.hash(&mut hasher);
    IntSeed(hasher.finish())
}

let int_seed = hash_seed_id(&id);
```

Finally, here is what the combined code ended up looking like:

```rust
use rand::{
    thread_rng, Rng,
    distributions::Uniform
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

const ID_LENGTH: usize = 10;

pub struct SeedId(pub String);

pub struct IntSeed(pub u64);

pub struct Seed {
    pub id: SeedId,
    pub int_seed: IntSeed
}

impl Seed {
    pub fn generate_seed() -> Self {
        let range = Uniform::new_inclusive(0, 35);

        let id = thread_rng()
            .sample_iter(&range)
            .take(ID_LENGTH)
            .map(|c: u8| map_to_id_char(c))
            .collect::<String>();

        let int_seed = hash_seed_id(&id);

        Seed {
            id: SeedId(id),
            int_seed
        }
    }
}

fn hash_seed_id<T: Hash>(id: &T) -> IntSeed {
    let mut hasher = DefaultHasher::new();
    id.hash(&mut hasher);
    IntSeed(hasher.finish())
}

fn map_to_id_char(num: u8) -> char {
    debug_assert!(num <= 35);
    match num {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        4 => 'E',
        5 => 'F',
        6 => 'G',
        7 => 'H',
        8 => 'I',
        9 => 'J',
        10 => 'K',
        11 => 'L',
        12 => 'M',
        13 => 'N',
        14 => 'O',
        15 => 'P',
        16 => 'Q',
        17 => 'R',
        18 => 'S',
        19 => 'T',
        20 => 'U',
        21 => 'V',
        22 => 'W',
        23 => 'X',
        24 => 'Y',
        25 => 'Z',
        26 => '0',
        27 => '1',
        28 => '2',
        29 => '3',
        30 => '4',
        31 => '5',
        32 => '6',
        33 => '7',
        34 => '8',
        35 => '9',
        _ => 'A'
    }
}
```

While this implementation is rather unremarkable and fairly straightforward, the problem itself is not exactly trivial, since it must take user experience into account, as well as the requirements of the RNG library used. I myself am still unsure if this approach provides an optimal user experience, but it seems to work well enough for existing randomizers, so I believe it will be sufficient for Mini-rando\'s needs.