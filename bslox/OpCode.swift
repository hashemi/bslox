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
    case negate
    case add, subtract, multiply, divide
}
