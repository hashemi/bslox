//
//  vm.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-04-06.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux) || CYGWIN
import Glibc
#endif

struct VM {
    var chunk = Chunk()
    var ip: Int = 0
    var stack: [Value] = []
    var hadRuntimeError = false
    
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
        self.hadRuntimeError = false
        
        return run()
    }

    mutating func run() -> InterpretResult {
        func readByte() -> OpCode {
            let byte = chunk.codes[ip]
            ip += 1
            return byte
        }
        
        func binaryOp(_ op: (Double, Double) -> Double) {
            guard
                case let .number(a) = stack[0],
                case let .number(b) = stack[1]
            else {
                runtimeError("Operands must be numbers")
                return
            }
            
            _ = stack.popLast()
            _ = stack.popLast()
            
            let res = op(a, b)
            stack.append(.number(res))
        }
        
        while true {
            #if DEBUG
            print("          " + stack.map { "[ \($0) ]" }.joined())
            print(chunk.disassemble(offset: ip))
            #endif
            
            guard !hadRuntimeError else { return .runtimeError }
            
            let instruction = readByte()
            switch instruction {
            case .return:
                print(stack.popLast()!)
                return .ok
                
            case let .constant(index: idx):
                stack.append(chunk.constants[Int(idx)])
                
            case .true:
                stack.append(.bool(true))

            case .false:
                stack.append(.bool(false))

            case .nil:
                stack.append(.nil)
                
            case .negate:
                guard case let .number(number) = stack.popLast()! else {
                    runtimeError("Operand must be a number.")
                    continue
                }
                
                stack.append(.number(-number))
                
            case .add: binaryOp(+)
            case .subtract: binaryOp(-)
            case .multiply: binaryOp(*)
            case .divide: binaryOp(/)
            }
        }
    }

    mutating func runtimeError(_ format: String, _ args: CVarArg...) {
        fputs(String(format: format, arguments: args), stderr)
        fputs("\n", stderr)
        fputs("[line \(chunk.lines[ip])]", stderr)
        
        hadRuntimeError = true
        stack.removeAll()
    }
}

