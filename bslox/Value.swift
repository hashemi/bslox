//
//  Value.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

enum Value: CustomStringConvertible, Equatable {
    case bool(Bool)
    case `nil`
    case number(Double)
    case string(String)
    
    var description: String {
        switch self {
        case let .bool(b): return b.description
        case .nil: return "nil"
        case let .number(n): return n.description
        case let .string(s): return s
        }
    }
    
    var isFalsey: Bool {
        switch self {
        case .nil: return true
        case .bool(false): return true
        default: return false
        }
    }
}
