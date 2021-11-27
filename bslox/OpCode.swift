//
//  OpCode.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

enum OpCode {
    case `return`
    case constant(index: UInt8)
    case `nil`, `true`, `false`
    case pop
    case not
    case equal, greater, less
    case negate
    case print
    case jump(jump: UInt16)
    case jumpIfFalse(jump: UInt16)
    case loop(jump: UInt16)
    case add, subtract, multiply, divide
    case getLocal(index: UInt8)
    case getGlobal(index: UInt8)
    case defineGlobal(index: UInt8)
    case setLocal(index: UInt8)
    case setGlobal(index: UInt8)
}
