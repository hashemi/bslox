//
//  vm.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

struct VM {
    var chunk = Chunk()
    var ip: Int = 0
    var stack: [Value] = []
    
    enum InterpretResult {
        case ok, compileError, runtimeError
    }

    mutating func interpret(_ source: String) -> InterpretResult {
        var newChunk = Chunk()
        
        guard compile(source, &newChunk) else {
            return .compileError
        }
        
        self.chunk = newChunk
        self.ip = 0
        
        return run()
    }

    mutating func run() -> InterpretResult {
        func readByte() -> OpCode {
            let byte = chunk.codes[ip]
            ip += 1
            return byte
        }
        
        func binaryOp(_ op: (Value, Value) -> Value) {
            let b = stack.popLast()!
            let a = stack.popLast()!
            let res = op(a, b)
            stack.append(res)
        }
        
        while true {
            #if DEBUG
            print("          " + stack.map { "[ \($0) ]" }.joined())
            print(chunk.disassemble(offset: ip))
            #endif

            let instruction = readByte()
            switch instruction {
            case .return:
                print(stack.popLast()!)
                return .ok
                
            case let .constant(index: idx):
                stack.append(chunk.constants[Int(idx)])
                
            case .negate:
                stack.append(-stack.popLast()!)
                
            case .add: binaryOp(+)
            case .subtract: binaryOp(-)
            case .multiply: binaryOp(*)
            case .divide: binaryOp(/)
            }
        }
    }
}
