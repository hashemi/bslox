//
//  Value.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

struct Value: ExpressibleByFloatLiteral, CustomStringConvertible {
    private let value: Double
    
    init(floatLiteral: Double) {
        self.value = floatLiteral
    }
    
    private init(_ value: Double) {
        self.value = value
    }
    
    var description: String {
        return String(format: "%g", value)
    }
    
    static prefix func -(v: Value) -> Value {
        return Value(-v.value)
    }
    
    static func +(lhs: Value, rhs: Value) -> Value {
        return Value(lhs.value + rhs.value)
    }

    static func -(lhs: Value, rhs: Value) -> Value {
        return Value(lhs.value - rhs.value)
    }

    static func *(lhs: Value, rhs: Value) -> Value {
        return Value(lhs.value * rhs.value)
    }

    static func /(lhs: Value, rhs: Value) -> Value {
        return Value(lhs.value / rhs.value)
    }
}
