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
    
    enum Precedence: Int, ExpressibleByNilLiteral {
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

        init(nilLiteral: ()) {
            self = .none
        }
    }
    
    enum PrefixParseFunction: ExpressibleByNilLiteral {
        case none, grouping, unary, string, number, variable,
             emitTrue, emitFalse, emitNil

        init(nilLiteral: ()) {
            self = .none
        }
    }
    
    func apply(_ prefix: PrefixParseFunction, _ canAssign: Bool) {
        switch prefix {
        case .none: fatalError("Unreachable")
        case .grouping: compileGrouping()
        case .unary: compileUnary()
        case .string: compileString()
        case .variable: compileVariable(canAssign)
        case .number: compileNumber()
        case .emitTrue: emitByte(.true)
        case .emitFalse: emitByte(.false)
        case .emitNil: emitByte(.nil)
        }
    }

    enum InfixParseFunction: ExpressibleByNilLiteral {
        case none, binary

        init(nilLiteral: ()) {
            self = .none
        }
    }

    func apply(_ infix: InfixParseFunction, _ canAssign: Bool) {
        switch infix {
        case .none: fatalError("Unreachable")
        case .binary: compileBinary()
        }
    }
    
    typealias ParseRule = (prefix: PrefixParseFunction, infix: InfixParseFunction, precedence: Precedence)

    let rules: [ParseRule] = [
        (.grouping,   nil,        .call),       // TOKEN_LEFT_PAREN
        (nil,         nil,        nil),         // TOKEN_RIGHT_PAREN
        (nil,         nil,        nil),         // TOKEN_LEFT_BRACE
        (nil,         nil,        nil),         // TOKEN_RIGHT_BRACE
        (nil,         nil,        nil),         // TOKEN_COMMA
        (nil,         nil,        .call),       // TOKEN_DOT
        (.unary,      .binary,    .term),       // TOKEN_MINUS
        (nil,         .binary,    .term),       // TOKEN_PLUS
        (nil,         nil,        nil),         // TOKEN_SEMICOLON
        (nil,         .binary,    .factor),     // TOKEN_SLASH
        (nil,         .binary,    .factor),     // TOKEN_STAR
        (.unary,       nil,       nil),         // TOKEN_BANG
        (nil,         .binary,    .equality),   // TOKEN_BANG_EQUAL
        (nil,         nil,        nil),         // TOKEN_EQUAL
        (nil,         .binary,    .equality),   // TOKEN_EQUAL_EQUAL
        (nil,         .binary,    .comparison), // TOKEN_GREATER
        (nil,         .binary,    .comparison), // TOKEN_GREATER_EQUAL
        (nil,         .binary,    .comparison), // TOKEN_LESS
        (nil,         .binary,    .comparison), // TOKEN_LESS_EQUAL
        (.variable,   nil,        nil),         // TOKEN_IDENTIFIER
        (.string,     nil,        nil),         // TOKEN_STRING
        (.number,     nil,        nil),         // TOKEN_NUMBER
        (nil,         nil,        .and),        // TOKEN_AND
        (nil,         nil,        nil),         // TOKEN_CLASS
        (nil,         nil,        nil),         // TOKEN_ELSE
        (.emitFalse,  nil,        nil),         // TOKEN_FALSE
        (nil,         nil,        nil),         // TOKEN_FUN
        (nil,         nil,        nil),         // TOKEN_FOR
        (nil,         nil,        nil),         // TOKEN_IF
        (.emitNil,    nil,        nil),         // TOKEN_NIL
        (nil,         nil,        .or),         // TOKEN_OR
        (nil,         nil,        nil),         // TOKEN_PRINT
        (nil,         nil,        nil),         // TOKEN_RETURN
        (nil,         nil,        nil),         // TOKEN_SUPER
        (nil,         nil,        nil),         // TOKEN_THIS
        (.emitTrue,   nil,        nil),         // TOKEN_TRUE
        (nil,         nil,        nil),         // TOKEN_VAR
        (nil,         nil,        nil),         // TOKEN_WHILE
        (nil,         nil,        nil),         // TOKEN_ERROR
        (nil,         nil,        nil),         // TOKEN_EOF
    ]

    var parser = Parser(
        previous: Token(type: .eof, text: source.prefix(upTo: source.startIndex), line: -1),
        current: Token(type: .eof, text: source.prefix(upTo: source.startIndex), line: -1),
        hadError: false,
        panicMode: false
    )
    
    advance()
    
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
    
    func check(_ token: TokenType) -> Bool {
        parser.current.type == token
    }
    
    func match(_ token: TokenType) -> Bool {
        guard check(token) else { return false }
        advance()
        return true
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
    
    func varDeclaration() {
        let global = parseVariable("Expect variable name.")
        
        if match(.equal) {
            expression()
        } else {
            emitByte(.nil)
        }
        consume(.semicolon, "Expect ';' after variable declaration.")
        
        defineVariable(global)
    }
    
    func expressionStatement() {
        expression()
        consume(.semicolon, "Expect ';' after expression.")
        emitByte(.pop)
    }
    
    func printStatement() {
        expression()
        consume(.semicolon, "Expect ';' after value.")
        emitByte(.print)
    }
    
    func synchronize() {
        parser.panicMode = false
        
        while parser.current.type != .eof {
            guard parser.previous.type != .semicolon else { return }
            switch parser.current.type {
            case .class, .fun, .var, .for, .if, .while, .print, .return:
                return
            default:
                break
            }
            
            advance()
        }
    }
    
    func declaration() {
        if match(.var) {
            varDeclaration()
        } else {
            statement()
        }
        
        if parser.panicMode {
            synchronize()
        }
    }
    
    func statement() {
        if match(.print) {
            printStatement()
        } else {
            expressionStatement()
        }
    }
    
    func compileNumber() {
        let v = Double(parser.previous.text)!
        emitConstant(.number(v))
    }
    
    func compileString() {
        let str = String(parser.previous.text.dropFirst().dropLast())
        emitConstant(.string(str))
    }
    
    func namedVariable(_ name: Token, _ canAssign: Bool) {
        let arg = identifierConstant(name)
        
        if canAssign && match(.equal) {
            expression()
            emitByte(.setGlobal(index: arg))
        } else {
            emitByte(.getGlobal(index: arg))
        }
    }
    
    func compileVariable(_ canAssign: Bool) {
        namedVariable(parser.previous, canAssign)
    }
    
    func compileGrouping() {
        expression()
        consume(.rightParen, "Expect ')' after expression.")
    }
    
    func compileUnary() {
        let opType = parser.previous.type
        
        // Compile the operand.
        parse(precedence: .unary)
        
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
        return rules[Int(type.rawValue)]
    }
    
    func parse(precedence: Precedence) {
        advance()
        
        let prefixRule = getRule(parser.previous.type).prefix
        guard prefixRule != .none else {
            error("Expect expression.")
            return
        }
        
        let canAssign = precedence.rawValue <= Precedence.assignment.rawValue
        apply(prefixRule, canAssign)
        
        while precedence.rawValue <= getRule(parser.current.type).precedence.rawValue {
            advance()

            let infixRule = getRule(parser.previous.type).infix
            if infixRule != .none  {
                apply(infixRule, canAssign)
            }
        }
        
        if canAssign && match(.equal) {
            error("Invalid assignment target.")
        }
    }
    
    func identifierConstant(_ name: Token) -> UInt8 {
        chunk.addConstant(Value.string(String(name.text)))
    }
    
    func parseVariable(_ errorMessage: String) -> UInt8 {
        consume(.identifier, errorMessage)
        return identifierConstant(parser.previous)
    }
    
    func defineVariable(_ global: UInt8) {
        emitByte(.defineGlobal(index: global))
    }
    
    func emitReturn() {
        emitByte(.return)
    }

    func emitConstant(_ value: Value) {
        emitByte(.constant(index: chunk.addConstant(value)))
    }
    
    while !match(.eof) {
        declaration()
    }
    end()
    
    guard !parser.hadError else { return false }
    
    return true
}
