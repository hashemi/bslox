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
    
    enum PrefixParseFunction {
        case grouping, unary, string, number, emitTrue, emitFalse, emitNil
    }
    
    func apply(_ prefix: PrefixParseFunction) {
        switch prefix {
        case .grouping: compileGrouping()
        case .unary: compileUnary()
        case .string: compileString()
        case .number: compileNumber()
        case .emitTrue: emitByte(.true)
        case .emitFalse: emitByte(.false)
        case .emitNil: emitByte(.nil)
        }
    }

    enum InfixParseFunction {
        case binary
    }

    func apply(_ infix: InfixParseFunction) {
        switch infix {
        case .binary: compileBinary()
        }
    }
    
    typealias ParseRule = (prefix: PrefixParseFunction?, infix: InfixParseFunction?, precedence: Precedence)
    let rules: [TokenType: ParseRule] = [
        .leftParen: (.grouping, nil, .call),
        .dot: (nil, nil, .call),
        .minus: (.unary, .binary, .term),
        .plus: (nil, .binary, .term),
        .slash: (nil, .binary, .factor),
        .star: (nil, .binary, .factor),
        .bang: (.unary, nil, .none),
        .bangEqual: (nil, .binary, .equality),
        .equalEqual: (nil, .binary, .equality),
        .greater: (nil, .binary, .comparison),
        .greaterEqual: (nil, .binary, .comparison),
        .less: (nil, .binary, .comparison),
        .lessEqual: (nil, .binary, .comparison),
        .string: (.string, nil, .none),
        .number: (.number, nil, .none),
        .and: (nil, nil, .and),
        .or: (nil, nil, .or),
        .true: (.emitTrue, nil, .none),
        .false: (.emitFalse, nil, .none),
        .nil: (.emitNil, nil, .none),
    ]

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
            fputs(" at '\(token.text)'", stderr)
        }
        
        fputs(": \(message)\n", stderr)
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
    
    func emitBytes(_ b1: OpCode, _ b2: OpCode) {
        emitByte(b1)
        emitByte(b2)
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
    
    func compileNumber() {
        let v = Double(parser.previous.text)!
        emitConstant(.number(v))
    }
    
    func compileString() {
        let str = String(parser.previous.text.dropFirst().dropLast())
        emitConstant(.string(str))
    }
    
    func compileGrouping() {
        expression()
        consume(.rightParen, "Expect ')' after expression.")
    }
    
    func compileUnary() {
        let opType = parser.previous.type
        
        // Compile the operand.
        parse(precedence: .assignment)
        
        // Emit the operator instruction.
        switch opType {
        case .minus: emitByte(.negate)
        case .bang: emitByte(.not)
        default:
            return // unreachable
        }
    }
    
    func compileBinary() {
        // Remember the operator.
        let opType = parser.previous.type
        
        // Compile the right operand.
        let rule = getRule(opType)
        parse(precedence: rule.precedence.higher)
        
        // Emit the operator instruction.
        switch opType {
        case .bangEqual:    emitBytes(.equal, .not)
        case .equalEqual:   emitByte(.equal)
        case .greater:      emitByte(.greater)
        case .greaterEqual: emitBytes(.less, .not)
        case .less:         emitByte(.less)
        case .lessEqual:    emitBytes(.greater, .not)
        case .plus:         emitByte(.add)
        case .minus:        emitByte(.subtract)
        case .star:         emitByte(.multiply)
        case .slash:        emitByte(.divide)
        default:
            return // Unreachable.
        }
    }

    func getRule(_ type: TokenType) -> ParseRule {
        return rules[type, default: (nil, nil, .none)]
    }
    
    func parse(precedence: Precedence) {
        advance()
        guard let prefixRule = getRule(parser.previous.type).prefix else {
            error("Expect expression.")
            return
        }
        
        apply(prefixRule)
        
        while precedence.rawValue <= getRule(parser.current.type).precedence.rawValue {
            advance()
            if let infixRule = getRule(parser.previous.type).infix {
                apply(infixRule)
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
