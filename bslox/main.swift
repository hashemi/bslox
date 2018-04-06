//
//  main.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-02-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

var vm = VM()

var chunk = Chunk()

let constant = chunk.addConstant(1.2)
chunk.write(.constant(index: constant), line: 123)

chunk.write(.return, line: 123)

_ = vm.interpret(chunk: chunk)
