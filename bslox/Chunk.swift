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
        
        func constant(_ opName: String, _ idx: UInt8) -> String {
            String(format: "%-16@ %4d '", opName, idx)
                + constants[Int(idx)].description
                + "'"
        }
        
        func byte(_ opName: String, _ idx: UInt8) -> String {
            String(format: "%-16@ %4d", opName, idx)
        }
        
        switch op {
        case .print:     result += "OP_PRINT"
        case .return:    result += "OP_RETURN"
        case .negate:    result += "OP_NEGATE"
        case .not:       result += "OP_NOT"
        case .add:       result += "OP_ADD"
        case .subtract:  result += "OP_SUBSTRACT"
        case .multiply:  result += "OP_MULTIPLY"
        case .divide:    result += "OP_DIVIDE"
        case .true:      result += "OP_TRUE"
        case .false:     result += "OP_FALSE"
        case .pop:       result += "OP_POP"
        case .getLocal(let idx):
            result += byte("OP_GET_LOCAL", idx)
        case .setLocal(let idx):
            result += byte("OP_SET_LOCAL", idx)
        case .getGlobal(let idx):
            result += constant("OP_GET_GLOBAL", idx)
        case .defineGlobal(let idx):
            result += constant("OP_DEFINE_GLOBAL", idx)
        case .nil:       result += "OP_NIL"
        case .setGlobal(let idx):
            result += constant("OP_SET_GLOBAL", idx)
        case .equal:     result += "OP_EQUAL"
        case .greater:   result += "OP_GREATER"
        case .less:      result += "OP_LESS"
        case .constant(let idx):
            result += constant("OP_CONSTANT", idx)
        }
        
        return result
    }
}
