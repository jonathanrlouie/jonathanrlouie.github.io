---
title:  Introduction to Rando
---

*Disclaimer: I do not support game piracy in any way. I simply believe that randomizers bring forth good ideas that can be applied to the creation of new games.*

## Introduction

Randomizers, as I have recently discovered, are actually quite interesting and have a bit more depth to them than I originally thought. As a result, I decided to try my hand at writing a blog focusing on them. This might include routing analysis, new gameplay ideas, and algorithms used in the making of randomizers.

## What is a randomizer?

Here is my definition of what a randomizer is:

A randomizer (often abbreviated as \"rando\") is modification of a game which introduces additional random elements, typically altering gameplay.

On its own, this definition is fairly broad, but I believe that its intentions are clear. It separates games which already contain random elements from their corresponding randomizers. Additionally, using this definition, we can distinguish between randomized games and games that use randomization as one of their core components, such as Roguelikes.

For many games, randomizers may alter item locations, statistics, game locations, and various other aspects. This randomization is intended to make old games more entertaining by making the game less static. Typically, randomizers use a seeded pseudo random number generator. This allows players to share seeds with each other such that they can both play through a game using the same randomization. This also allows players to race each other to see who can complete a given seed faster, or cooperate to complete a seed as quickly as possible. There are even some randomizers that allow cooperating players to have [linked inventories](http://alttp.mymm1.com/emu-coop/), such that if one player picks up an item, the other player gets it as well. A number of randomizers also allow players to make manual changes to the game in place of the randomizer (sometimes called \"plando\").

## A brief history of randomizers

Based on the earliest [GitHub commits](https://github.com/Dessyreqt/smrandomizer/commits/master?after=d792943da96e895f3ae97adae15c71aa0f666104+69) I have found, it appears that the first ever randomizer was created in 2012. It was for the classic SNES game Super Metroid. It was a simple item randomizer that changed the locations of key items, forcing players to route the game in a completely different way from the original game\'s optimal routing. In the coming years, many different randomizers would be created for various different games, such as randomizers for the Pokemon series, the Legend of Zelda series, and even several Indie titles, such as Rabi-Ribi and La-Mulana. [Here](https://www.debigare.com/randomizers/) is a fairly comprehensive list of known randomizers. As you can see, they are quite plentiful!

Randomizer races appear to have existed since the early days of randomizer. The [earliest footage](https://www.youtube.com/watch?v=XCLS6NZMq2o) I could find was a Super Metroid randomizer race from 2013. However, only in recent years have they become much more prevalent. In 2016, a randomizer for the SNES game The Legend of Zelda: A Link to the Past (from here on referred to as ALTTP) was released. This randomizer, like the Super Metroid one, could be used to randomize key item locations, creating many unique scenarios and offering players a plethora of routing choices. Due the layout of the world in ALTTP, the large number of fairly unique key items, as well as the already well established fanbase for the original game, it very quickly grew in popularity. It currently sits as one of (if not) the most popular randomizers for racing.

Now, in 2018, there exists a [Super Metroid and ALTTP crossover randomizer](https://alttsm.speedga.me/), where players can transition between the two games through certain entrances and collect items for one game in the other game. Since the goal is to complete both games, seeds can take a long time to complete. However, the sheer novelty of this randomizer has attracted the attention of a number of runners all the same. As this is the first known crossover randomizer, I would say that we live in very exciting times!

As a side note, due to the success of item randomizers, I will focus mostly on them in the future, though I may talk about other randomizer modes from time to time. I personally think that some of the wackier randomizers can also be very fun :)

## What makes rando so interesting

For many years, people have been competing to see who can complete a game the fastest. In the context of speedrunning, randomness in games typically makes the timing of speedruns inconsistent. This has caused games with little to no RNG to be favoured as speed games. As a result, most popular speed games are entirely centered around execution, with a handful of players who dominate the leaderboards. Randomizers, such as the ALTTP randomizer and the Super Metroid randomizer, make games no longer entirely execution centric, but more routing centric. While execution is still a very important factor, games are no longer played using the same optimal route every single run. This gives players with worse execution a chance to win by making better routing decisions or taking gambles. This creates much more interesting race results where the same few players do not always win every game. This balance of luck, execution, and routing is what appeals to both casual players and speedrunners alike.

It is important to note that randomizers can also be very fun spectator games as well. Due to the time consuming and difficult nature of some randomizers, spectating is how some people enjoy the games without having to actually play the randomizers themselves. It can also be very interesting to see how different players route certain seeds, as well as discover how a randomizer has changed a game. For item randomizers in particular, viewers tend to enjoy trying to follow the logic of particular seeds and speculating which items will be in certain locations. They also tend to enjoy when items appear in very suboptimal (or \"troll\") locations. For these reasons, randomizers have become fairly popular among streamers.

## Looking ahead

Currently, randomizers are all modifications of games, but I think that there is still some untapped potential in this area. Randomizers face many limitations, such as legal concerns, not having methods of completely prevent cheating, and needing to be faithful to the original game. By borrowing some ideas from randomizers, I believe that new games can be built without these limitations and can even include additional quality of life functionality and gameplay improvements that randomized games do not typically have.