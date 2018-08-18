//
//  Compiler.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-05-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux) || CYGWIN
import Glibc
#endif

func compile(_ source: String, _ chunk: inout Chunk) -> Bool {
    var scanner = Scanner(source)
    
    struct Parser {
        var previous: Token
        var current: Token
        var hadError: Bool
        var panicMode: Bool
    }
    
    enum Precedence: Int {
        case none
        case assignment  // =
        case or          // or
        case and         // and
        case equality    // == !=
        case comparison  // < > <= >=
        case term        // + -
        case factor      // * /
        case unary       // ! - +
        case call        // . () []
        case primary
        
        var higher: Precedence {
            return Precedence(rawValue: self.rawValue + 1)!
        }
    }
    
    typealias ParseFn = () -> ()
    typealias ParseRule = (prefix: ParseFn?, infix: ParseFn?, precedence: Precedence)
    var rules: [TokenType: ParseRule] = [:]
    
    var parser = Parser(
        previous: Token(type: .eof, text: source.prefix(upTo: source.startIndex), line: -1),
        current: scanner.scanToken(),
        hadError: false,
        panicMode: false
    )
    
    func error(_ message: String) {
        errorAt(parser.previous, message)
    }
    
    func errorAtCurrent(_ message: String) {
        errorAt(parser.current, message)
    }
    
    func errorAt(_ token: Token, _ message: String) {
        guard !parser.panicMode else { return }
        parser.panicMode = true
        
        fputs("[line \(token.line)] Error", stderr)
    
        switch token.type {
        case .eof:
            fputs(" at end", stderr)
        case .error:
            // Nothing.
            break
        default:
            fputs("at '\(token.text)'", stderr)
        }
        
        fputs(": \(message)", stderr)
        parser.hadError = true
    }
    
    func advance() {
        parser.previous = parser.current
        
        while true {
            parser.current = scanner.scanToken()
            if parser.current.type != .error { break }
            
            errorAtCurrent(String(parser.current.text))
        }
    }
    
    func consume(_ type: TokenType , _ message: String) {
        guard parser.current.type == type else {
            errorAtCurrent(message)
            return
        }

        advance()
    }
    
    func emitByte(_ byte: OpCode) {
        chunk.write(byte, line: parser.previous.line)
    }
    
    func end() {
        emitReturn()
        #if DEBUG
        if !parser.hadError {
            print(chunk.disassemble(name: "code"))
        }
        #endif
    }
    
    func expression() {
        parse(precedence: .assignment)
    }
    
    func number() {
        let v = Double(parser.previous.text)!
        emitConstant(.number(v))
    }
    
    func grouping() {
        expression()
        consume(.rightParen, "Expect ')' after expression.")
    }
    
    func unary() {
        let opType = parser.previous.type
        
        // Compile the operand.
        parse(precedence: .assignment)
        
        // Emit the operator instruction.
        switch opType {
        case .minus: emitByte(.negate)
        default:
            return // unreachable
        }
    }
    
    func binary() {
        // Remember the operator.
        let opType = parser.previous.type
        
        // Compile the right operand.
        let rule = getRule(opType)
        parse(precedence: rule.precedence.higher)
        
        // Emit the operator instruction.
        switch opType {
        case .plus:  emitByte(.add)
        case .minus: emitByte(.subtract)
        case .star:  emitByte(.multiply)
        case .slash: emitByte(.divide)
        default:
            return // Unreachable.
        }
    }
    
    rules[.leftParen] = (grouping, nil, .call)
    rules[.dot] = (nil, nil, .call)
    rules[.minus] = (unary, binary, .term)
    rules[.plus] = (nil, binary, .term)
    rules[.slash] = (nil, binary, .factor)
    rules[.star] = (nil, binary, .factor)
    rules[.bangEqual] = (nil, nil, .equality)
    rules[.equalEqual] = (nil, nil, .equality)
    rules[.greater] = (nil, nil, .comparison)
    rules[.greaterEqual] = (nil, nil, .comparison)
    rules[.less] = (nil, nil, .comparison)
    rules[.lessEqual] = (nil, nil, .comparison)
    rules[.number] = (number, nil, .none)
    rules[.and] = (nil, nil, .and)
    rules[.or] = (nil, nil, .or)
    rules[.true] = ({ emitByte(.true) }, nil, .none)
    rules[.false] = ({ emitByte(.false) }, nil, .none)
    rules[.nil] = ({ emitByte(.nil) }, nil, .none)

    func getRule(_ type: TokenType) -> ParseRule {
        return rules[type] ?? (nil, nil, .none)
    }
    
    func parse(precedence: Precedence) {
        advance()
        guard let prefixRule = getRule(parser.previous.type).prefix else {
            error("Expect expression.")
            return
        }
        
        prefixRule()
        
        while precedence.rawValue <= getRule(parser.current.type).precedence.rawValue {
            advance()
            if let infixRule = getRule(parser.previous.type).infix {
                infixRule()
            }
        }
    }
    
    func emitReturn() {
        emitByte(.return)
    }

    func emitConstant(_ value: Value) {
        emitByte(.constant(index: chunk.addConstant(value)))
    }
    
    expression()
    consume(.eof, "Expect end of expression.")
    end()
    
    guard !parser.hadError else { return false }
    
    return true
}
