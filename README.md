# bslox

This project follows Bob Nystrom's excellent book, [Crafting Interpreters](http://www.craftinginterpreters.com) which takes you through the process of writing an interpreter for a language called Lox.

The book describes two implementations. The first in Java and is a tree-walking interpreter. I have ported that version to Swift in my other project, [slox](https://github.com/hashemi/slox). The final part of the book describes a bytecode interpreter in C. This is my Swift port of the bytecode interpreter. I also ported this bytecode interpreter to C++ in [cloxpp](https://github.com/hashemi/cloxpp).

The book is being released as chapters are completed, one chapter at a time.

## Progress
Code from the following chapters is implemented in this port:

14. Chunks of Bytecode.
15. A Virtual Machine.
16. Scanning on Demand.
17. Compiling Expressions.
18. Types of Values.
19. Strings.
20. Hash Tables. (no code required, will use `Dictionary`)
21. Global Variables.
22. Local Variables.

## Tests

The test suite is from the reference C implementation. To run the tests:

```zsh
dart tool/bin/test.dart chap22_local --interpreter .build/release/bslox
```

The command specifies `.build/release/bslox` as the binary, which is where it ends up after running this command to compile the code:'

```zsh
swift build -c release
```

For the test suite to run, you need to have the Dart programming language SDK installed. After that, you need to get the test runners dependencies by going to the `tool` directory and running:

```zsh
pub get
```

## Goals & Design
The goal is to get as close as possible to the C reference implementation in performance, while taking advantage of Swift's features.

## License
MIT
