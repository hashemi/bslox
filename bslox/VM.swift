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
    var globals: [String: Value] = [:]
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
        
        func readString(_ idx: UInt8) -> String {
            guard case .string(let name) = chunk.constants[Int(idx)] else {
                fatalError("Unreachable")
            }
            return name
        }
        
        func numbersBinaryOp(_ op: (Double, Double) -> Value) {
            guard
                case let .number(b) = peek(0),
                case let .number(a) = peek(1)
            else {
                runtimeError("Operands must be numbers.")
                return
            }

            popTwoAndAppend(op(a, b))
        }
        
        func popTwoAndAppend(_ v: Value) {
            _ = stack.popLast()
            _ = stack.popLast()
            stack.append(v)
        }
        
        func peek(_ depth: Int) -> Value {
            return stack[stack.count - depth - 1]
        }
        
        while true {
            #if DEBUG
            print("          " + stack.map { "[ \($0) ]" }.joined())
            print(chunk.disassemble(offset: ip))
            #endif
            
            guard !hadRuntimeError else { return .runtimeError }
            
            let instruction = readByte()
            switch instruction {
            case .print:
                print(stack.popLast()!)

            case .jump(let offset):
                ip += Int(offset)
                
            case .jumpIfFalse(let offset):
                if peek(0).isFalsey { ip += Int(offset) }

            case .loop(let offset):
                ip -= Int(offset)
                
            case .return:
                return .ok
                
            case let .constant(index: idx):
                stack.append(chunk.constants[Int(idx)])
                
            case .true:
                stack.append(.bool(true))

            case .false:
                stack.append(.bool(false))

            case .pop:
                _ = stack.popLast()!

            case let .getLocal(index: idx):
                stack.append(stack[Int(idx)])
                
            case let .getGlobal(index: idx):
                let name = readString(idx)
                guard let value = globals[name] else {
                    runtimeError("Undefined variable '\(name)'.")
                    return .runtimeError
                }
                stack.append(value)
                
            case let .defineGlobal(index: idx):
                let name = readString(idx)
                globals[name] = stack.popLast()!
                
            case let .setLocal(index: idx):
                stack[Int(idx)] = peek(0)
                
            case let .setGlobal(index: idx):
                let name = readString(idx)
                guard globals.updateValue(peek(0), forKey: name) != nil else {
                    globals.removeValue(forKey: name)
                    runtimeError("Undefined variable '\(name)'.")
                    return .runtimeError
                }
                
            case .equal:
                let b = peek(0)
                let a = peek(1)
                popTwoAndAppend(.bool(a == b))
                
            case .greater: numbersBinaryOp { .bool( $0 > $1 ) }
            case .less: numbersBinaryOp { .bool( $0 < $1 ) }
            
            case .nil:
                stack.append(.nil)
            
            case .not:
                stack.append(.bool(stack.popLast()!.isFalsey))
                
            case .negate:
                guard case let .number(number) = stack.popLast()! else {
                    runtimeError("Operand must be a number.")
                    continue
                }
                
                stack.append(.number(-number))
                
            case .add:
                switch (peek(0), peek(1)) {
                case let (.number(b), .number(a)):
                    popTwoAndAppend(.number(a + b))
                case let (.string(b), .string(a)):
                    popTwoAndAppend(.string(a + b))
                default:
                    runtimeError("Operands must be two numbers or two strings.")
                    continue
                }

            case .subtract: numbersBinaryOp { .number( $0 - $1 ) }
            case .multiply: numbersBinaryOp { .number( $0 * $1 ) }
            case .divide: numbersBinaryOp { .number( $0 / $1 ) }
            }
        }
    }

    mutating func runtimeError(_ format: String, _ args: CVarArg...) {
        fputs(String(format: format, arguments: args), stderr)
        fputs("\n", stderr)
        fputs("[line \(chunk.lines[ip])] in script\n", stderr)
        
        hadRuntimeError = true
        stack.removeAll()
    }
}

