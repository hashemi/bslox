
# bslox

This project follows Bob Nystrom's excellent book, [Crafting Interpreters](http://www.craftinginterpreters.com) which takes you through the process of writing an interpreter for a language called Lox.

The book describes two implementations. The first in Java and is a tree-walking interpreter. I have already ported that version to Swift in my other project, [slox](https://github.com/hashemi/slox). The final part of the book describes a bytecode interpreter in C. This is my Swift port of the bytecode interpreter.

The book is being released as chapters are completed, one chapter at a time.

## Progress
As of May 20th, 2018, this version is up to date with Part III of the book. It implements the following chapters:

14. Chunks of Bytecode.
15. A Virtual Machine.
16. Scanning on Demand.

## Goals & Design
As with my other port, I will sometimes deviate from the C implementation to take advantage of Swift's features and idioms. For example, instead of storing a constant's index inline with the bytecode, it's stored as an associated value. This may lead to less compact bytecode array. I will revisit this decision as we progress through other chapters.

## License
MIT
