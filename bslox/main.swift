//
//  main.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-02-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

var vm = VM()

var chunk = Chunk()

var constant = chunk.addConstant(1.2)
chunk.write(.constant(index: constant), line: 123)

constant = chunk.addConstant(3.4)
chunk.write(.constant(index: constant), line: 123)

chunk.write(.add, line: 123)

constant = chunk.addConstant(5.6)
chunk.write(.constant(index: constant), line: 123)

chunk.write(.divide, line: 123)
chunk.write(.negate, line: 123)

chunk.write(.return, line: 123)

_ = vm.interpret(chunk: chunk)
