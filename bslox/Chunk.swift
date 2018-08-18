//
//  Chunk.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

import Foundation

struct Chunk {
    var codes: [OpCode] = []
    var lines = CompressedArray<Int>()
    var constants: [Value] = []
    
    mutating func write(_ op: OpCode, line: Int) {
        codes.append(op)
        lines.append(line)
    }
    
    mutating func addConstant(_ value: Value) -> UInt8 {
        constants.append(value)
        return UInt8(constants.count - 1)
    }
    
    func disassemble(name: String) -> String {
        return "== \(name) ==\n" +
            (0..<codes.count).map {
                String(format: "%04d ", $0) + disassemble(offset: $0)
                }.joined(separator: "\n")
    }
    
    func disassemble(offset: Int) -> String {
        let op = codes[offset]
        
        var result: String
        if (offset > 0 && lines[offset] == lines[offset - 1]) {
            result = "   | "
        } else {
            result = String(format: "%4d ", lines[offset])
        }
        
        switch op {
        case .return:    result += "OP_RETURN"
        case .negate:    result += "OP_NEGATE"
        case .add:       result += "OP_ADD"
        case .subtract:  result += "OP_SUBSTRACT"
        case .multiply:  result += "OP_MULTIPLY"
        case .divide:    result += "OP_DIVIDE"
        case .constant(let constant):
            result += String(format: "%-16@ %4d '", "OP_CONSTANT", constant)
                + constants[Int(constant)].description
                + "'"
        }
        
        return result
    }
}
