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
    
    var description: String {
        return String(format: "%g", value)
    }
}
