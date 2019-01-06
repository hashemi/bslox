# bslox

This project follows Bob Nystrom's excellent book, [Crafting Interpreters](http://www.craftinginterpreters.com) which takes you through the process of writing an interpreter for a language called Lox.

The book describes two implementations. The first in Java and is a tree-walking interpreter. I have already ported that version to Swift in my other project, [slox](https://github.com/hashemi/slox). The final part of the book describes a bytecode interpreter in C. This is my Swift port of the bytecode interpreter.

The book is being released as chapters are completed, one chapter at a time.

## Progress
As of Sep 24th, 2018, `bslox` is up to date with the released chapters of Part III, implementing the following chapters:

14. Chunks of Bytecode.
15. A Virtual Machine.
16. Scanning on Demand.
17. Compiling Expressions.
18. Types of Values.
19. Strings.
20. Hash Tables. (no code required, will use `Dictionary`)

## Goals & Design
As with my other port, I will sometimes deviate from the C implementation to take advantage of Swift's features and idioms. For example, instead of storing a constant's index inline with the bytecode, it's stored as an associated value. This may lead to less compact bytecode array. I also managed to omit a lot of boilerplate code from the C version and used Swift features instead. For example, I used Swift's `String` type, which hides a lot of the complexity of memory management, etc using low-cost/zero-cost abstractinos. I plan to revisit those decisions at some point and analyze the performance tradeoffs. The ultimate goal is for this Swift version to perform on par with the C version while managing a lot of the complexity using zero-cost abstractions.

## License
MIT
