---
layout: post
title:  "The Concurrency Conundrum"
date:   2019-06-23 15:00:00 -0700
categories: Concurrency, Green thread, Fiber, Future, Promise
---

Alternate title: Learning About Concurrent Programming Feels Terrible

Reading technical literature, such as blog posts and articles, is all about filtering out incorrect information. People disagree about concepts all the time, and it can be extremely confusing to figure out which definition is "correct". Often, terminologies are mixed up between different languages too, leading to confusing situations, such as Void in Haskell vs. void in C++. Usually, I have found that people tend come to a consensus on these sorts of issues, so it's easy to find a "correct" answer. However, when it comes to concurrency, it seems that there is no consensus and people have their own definitions of certain concepts, like green threads and fibers or futures and promises, which makes learning about these concepts incredibly frustrating. This post is about my struggles with learning about these concepts.

## Green Threads vs. Fibers

Consider these two pages here:

https://tokio.rs/docs/futures/spawning/

https://stackoverflow.com/questions/37285366/green-threads-in-net

In the first link, you can see this definition of a Tokio task:

*A task is a small unit of logic that executes independently from other tasks. It is similar to Go’s goroutine and Erlang’s process, but asynchronous. In other words, tasks are asynchronous green threads.*

... but if you look at the other link here:

![Goroutines Not Green Threads Screenshot](/Assets/ConcurrencyConundrum/GoroutinesNotGreenThreads.PNG)

They completely disagree! As you can see in this comment, Go and Erlang have *no* green threads. It's even been upvoted 5 times! It calls out other sources that state that goroutines and Erlang processes are green threads as being "wrong". So who the heck are we supposed to believe? After poking around for a bit, I believe the majority of people believe that these constructs *are* green threads. The [Wikipedia page](https://en.wikipedia.org/wiki/Green_threads) on green threads simply states that they are "threads" that are scheduled by a runtime library or virtual machine, instead of the OS.

Another term I've seen fairly often is "fiber". Looking at Wikipedia, a fiber is simply "a particularly lightweight thread of execution" which share address space and use cooperative multitasking. That's all well and fine, but here's a question: Can green threads also be fibers? This is a question that doesn't seem to have any conclusive answer. [This article](https://www.fpcomplete.com/blog/2017/01/green-threads-are-like-garbage-collection) from FP Complete seems to suggest that they are distinct, and you can distinguish them based on whether they use cooperative or pre-emptive multitasking. Here are the excerpts suggesting this:

*That may sound like a lot to deliver on, but green threads are up to the challenge. They are very similar to the fibers that we described above, with one major difference: seemingly blocking I/O calls actually use non-blocking I/O under the surface.*

*Since the runtime system is handling the scheduling of threads, it is free to determine that a thread has been active for too long and pause execution in favor of a different thread, solving the long CPU processing problem mentioned above. (This is also the difference between cooperative and preemptive multithreading.)*

However, [this recently published book](https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/green-threads) on green threads states the following:

*Non-preemptive multitasking.*

*This is what we’ll talk about today. A task decides by itself when the CPU would be better off doing something else than waiting for something to happen in the current task. Commonly this is done by yielding control to the scheduler. A normal use case for this is to yield control when something that will block execution occurs. An example of this is IO operations. When the control is yielded a central scheduler direct the CPU to resume work on another task that is ready to actually do something else than just block.*

Remember, this is talking specifically about "green threads". The introduction of this book even states the following:

*Green threads, userland threads, goroutines or fibers, they have many names but for simplicity’s sake I’ll refer to them all as green threads from now on.*

I've also seen other examples where people have asserted that green threads are the same as fibers, such as the README for the [mioco project](https://github.com/dpc/mioco). This is in direct contradiction with the FP Complete article. So what really is a green thread? It looks like the definition might actually be more context sensitive than what Wikipedia and the FP Complete article suggest. I dug into this a little bit further and found [this issue](https://github.com/golang/go/issues/11462). According to this issue, as long as we're willing to believe that a goroutine is a green thread, then green threads can be "partially pre-emptive". So it seems that we can't really define a green thread by how it is scheduled. The only thing that people generally seem to agree upon is what Wikipedia says, so this would imply that a green thread could indeed be a fiber. However, take a look at Wikipedia's [discussion page on fibers](https://en.wikipedia.org/wiki/Talk:Fiber_(computer_science)).

![Fiber Discussion Screenshot](/Assets/ConcurrencyConundrum/FiberDiscussion.PNG)

This thread (no pun intended) indicates that there really isn't a concrete definition of a fiber at all. Indeed, after poking around a bit more, I found [this issue](https://github.com/crystal-lang/crystal/issues/1454) titled "Fiber pre-emption, blocking calls and other concurrency issues", which suggests that fibers could use pre-emptive multitasking. This seems to explain why we are seeing these conflicting definitions.

## The Meaning of "Blocking"

Another confusing situation I've encountered with green threads involves the notion of "blocking". Many sources mention that blocking on a green thread will block the entire OS thread. Others say that we can block on a green thread and it will not block the entire OS thread. Thankfully, this scenario is explained quite well in [this issue](https://github.com/typelevel/cats-effect/issues/243). As SystemFw says here:

*I think the reason they confuse you is because they are talking about blocking on different levels.

"As Haskell’s runtime uses green threading, a synchronous IO (and the requisite thread blocking) makes a lot of sense."

thread blocking here means blocking a green thread , so this is basically the second part of point 4.

"When a green thread executes a blocking system call, not only is that thread blocked, but all of the threads within the process are blocked.[5] To avoid that problem, green threads must use asynchronous I/O operations, ..."

blocking system call here means blocking an OS thread/OS process, this is bad because the whole OS thread yields back control, and there are multiple green threads multiplexed on it, so all those green threads are blocked, on the layer above.*

So when someone talks about "blocking" on a thread, it is important to disambiguate what level of blocking they are talking about.

## Future vs. Promise

Finally, what is the difference between a Future and a Promise? Well, as it turns out, this completely depends on what language we're talking about. According to [this Reddit post](https://www.reddit.com/r/scala/comments/aznvcd/should_i_know_the_difference_between_a_promise/), a Future in Scala is the same as a Promise in JavaScript. So what is a Promise in Scala? It's apparently the same as something called "Deferred" in JavaScript. So Rust's Future is analogous to Scala's Future, which is analogous to JavaScript's Promise. The [Wikipedia page](https://en.wikipedia.org/wiki/Futures_and_promises) on this explains it as follows: "The terms future, promise, delay, and deferred are often used interchangeably, although some differences in usage between future and promise are treated below. Specifically, when usage is distinguished, a future is a read-only place-holder view of a variable, while a promise is a writeable, single assignment container which sets the value of the future". So, from what I can tell, there is usually no difference between a Promise and a Future, unless a language contains both Promises and Futures as two separate concepts. There's absolutely no way this could ever confuse anyone, right? :)

## Conclusion

It seems that these terms have been invented in recent years and used very informally, hence why they do not really seem to have consistent definitions. My hope is that some of these terms become more concretely defined, but for now, we just have to live with their informal definitions. In the future, I think I will try to avoid using general terms like "green thread" or "fiber" if I can help it, since most languages have their own implementations of these concepts with specific names anyway.