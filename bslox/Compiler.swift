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
        case none, binary, and, or

        init(nilLiteral: ()) {
            self = .none
        }
    }

    func apply(_ infix: InfixParseFunction, _ canAssign: Bool) {
        switch infix {
        case .none: fatalError("Unreachable")
        case .binary: compileBinary()
        case .and: compileAnd()
        case .or: compileOr()
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
        (nil,         .and,       .and),        // TOKEN_AND
        (nil,         nil,        nil),         // TOKEN_CLASS
        (nil,         nil,        nil),         // TOKEN_ELSE
        (.emitFalse,  nil,        nil),         // TOKEN_FALSE
        (nil,         nil,        nil),         // TOKEN_FUN
        (nil,         nil,        nil),         // TOKEN_FOR
        (nil,         nil,        nil),         // TOKEN_IF
        (.emitNil,    nil,        nil),         // TOKEN_NIL
        (nil,         .or,        .or),         // TOKEN_OR
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

    struct Local {
        let name: Token
        var depth: Int
    }
    
    struct Compiler {
        var locals: [Local] = []
        var scopeDepth: Int = 0
        
        static var current = Compiler()
    }
    
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
    
    func emitLoop(_ loopStart: Int) {
        var offset = chunk.codes.count - loopStart + 1
        if offset > UInt16.max {
            error("Loop body too large.")
            offset = Int(UInt16.max)
        }
        emitByte(.loop(jump: UInt16(offset)))
    }
    
    func emitJump(_ instruction: OpCode) -> Int {
        emitByte(instruction)
        return chunk.codes.count - 1
    }
    
    func end() {
        emitReturn()
        #if DEBUG
        if !parser.hadError {
            print(chunk.disassemble(name: "code"))
        }
        #endif
    }
    
    func beginScope() {
        Compiler.current.scopeDepth += 1
    }
    
    func endScope() {
        Compiler.current.scopeDepth -= 1
        
        while let depth = Compiler.current.locals.last?.depth,
              depth > Compiler.current.scopeDepth {
            emitByte(.pop)
            _ = Compiler.current.locals.popLast()
        }
    }
    
    func expression() {
        parse(precedence: .assignment)
    }
    
    func block() {
        while !check(.rightBrace) && !check(.eof) {
            declaration()
        }
        
        consume(.rightBrace, "Expect '}' after block.")
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
    
    func forStatement() {
        beginScope()
        consume(.leftParen, "Expect '(' after 'for'.")
        if match(.semicolon) {
            // No initializer
        } else if match(.var) {
            varDeclaration()
        } else {
            expressionStatement()
        }
        
        var loopStart = chunk.codes.count
        var exitJump = -1
        if !match(.semicolon) {
            expression()
            consume(.semicolon, "Expect ';' after loop condition.")
            
            // Jump out of the loop if the condition is false
            exitJump = emitJump(.jumpIfFalse(jump: .max))
            emitByte(.pop)
        }
        
        if !match(.rightParen) {
            let bodyJump = emitJump(.jump(jump: .max))
            let incrementStart = chunk.codes.count
            expression()
            emitByte(.pop)
            consume(.rightParen, "Expect ')' after for clause.")
            
            emitLoop(loopStart)
            loopStart = incrementStart
            patchJump(bodyJump)
        }
        
        statement()
        emitLoop(loopStart)
        
        if exitJump != -1 {
            patchJump(exitJump)
            emitByte(.pop)
        }
        
        endScope()
    }
    
    func ifStatement() {
        consume(.leftParen, "Expect '(' after 'if'.")
        expression()
        consume(.rightParen, "Expect ')' after condition.")
        
        let thenJump = emitJump(.jumpIfFalse(jump: .max))
        emitByte(.pop)
        statement()
        
        let elseJump = emitJump(.jump(jump: .max))
        
        patchJump(thenJump)
        emitByte(.pop)

        if match(.else) { statement() }
        patchJump(elseJump)
    }
    
    func printStatement() {
        expression()
        consume(.semicolon, "Expect ';' after value.")
        emitByte(.print)
    }
    
    func whileStatement() {
        let loopStart = chunk.codes.count
        consume(.leftParen, "Expect '(' after 'while'.")
        expression()
        consume(.rightParen, "Expect ')' after condition.")
        
        let exitJump = emitJump(.jumpIfFalse(jump: .max))
        emitByte(.pop)
        statement()
        emitLoop(loopStart)
        
        patchJump(exitJump)
        emitByte(.pop)
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
        } else if match(.for) {
            forStatement()
        } else if match(.if) {
            ifStatement()
        } else if match(.while) {
            whileStatement()
        } else if match(.leftBrace) {
            beginScope()
            block()
            endScope()
        } else {
            expressionStatement()
        }
    }
    
    func compileNumber() {
        let v = Double(parser.previous.text)!
        emitConstant(.number(v))
    }
    
    func compileOr() {
        let elseJump = emitJump(.jumpIfFalse(jump: .max))
        let endJump = emitJump(.jump(jump: .max))
        
        patchJump(elseJump)
        emitByte(.pop)
        
        parse(precedence: .or)
        patchJump(endJump)
    }
    
    func compileString() {
        let str = String(parser.previous.text.dropFirst().dropLast())
        emitConstant(.string(str))
    }
    
    func namedVariable(_ name: Token, _ canAssign: Bool) {
        let getOp: OpCode
        let setOp: OpCode
        
        let arg = resolveLocal(Compiler.current, name)
        if arg != -1 {
            getOp = .getLocal(index: UInt8(arg))
            setOp = .setLocal(index: UInt8(arg))
        } else {
            let arg = identifierConstant(name)
            getOp = .getGlobal(index: arg)
            setOp = .setGlobal(index: arg)
        }
        
        if canAssign && match(.equal) {
            expression()
            emitByte(setOp)
        } else {
            emitByte(getOp)
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
    
    func addLocal(_ name: Token) {
        if Compiler.current.locals.count == (Int(UInt8.max) + 1) {
            error("Too many local variables in function.")
            return
        }
        
        let local = Local(name: name, depth: -1)
        Compiler.current.locals.append(local)
    }
    
    func declareVariable() {
        if Compiler.current.scopeDepth == 0 { return }

        let name = parser.previous

        for i in (0..<Compiler.current.locals.count).reversed() {
            let local = Compiler.current.locals[i]
            if local.depth != -1 && local.depth < Compiler.current.scopeDepth {
                break
            }
            
            if local.name.text == name.text {
                error("Already a variable with this name in this scope.")
            }
        }
        
        addLocal(name)
    }
    
    func resolveLocal(_ compiler: Compiler, _ name: Token) -> Int {
        for i in (0..<Compiler.current.locals.count).reversed() {
            let local = Compiler.current.locals[i]
            if name.text == local.name.text {
                if local.depth == -1 {
                    error("Can't read local variable in its own initializer.")
                }
                return i
            }
        }
        
        return -1
    }
    
    func parseVariable(_ errorMessage: String) -> UInt8 {
        consume(.identifier, errorMessage)
        
        declareVariable()
        if Compiler.current.scopeDepth > 0 { return 0 }
        
        return identifierConstant(parser.previous)
    }
    
    func markInitialized() {
        Compiler.current.locals[Compiler.current.locals.count - 1].depth = Compiler.current.scopeDepth
    }
    
    func defineVariable(_ global: UInt8) {
        if Compiler.current.scopeDepth > 0 {
            markInitialized()
            return
        }
        
        emitByte(.defineGlobal(index: global))
    }
    
    func compileAnd() {
        let endJump = emitJump(.jumpIfFalse(jump: .max))
        
        emitByte(.pop)
        parse(precedence: .and)
        
        patchJump(endJump)
    }
    
    func emitReturn() {
        emitByte(.return)
    }

    func emitConstant(_ value: Value) {
        emitByte(.constant(index: chunk.addConstant(value)))
    }
    
    func patchJump(_ offset: Int) {
        var jump = chunk.codes.count - offset - 1
        
        if jump > UInt16.max {
            error("Too much code to jump over.")
            jump = Int(UInt16.max)
        }
        
        switch chunk.codes[offset] {
        case .jump:
            chunk.codes[offset] = .jump(jump: UInt16(jump))
        case .jumpIfFalse:
            chunk.codes[offset] = .jumpIfFalse(jump: UInt16(jump))
        default:
            fatalError("Can't patch a \(chunk.codes[offset]) instruction.")
        }
    }
    
    while !match(.eof) {
        declaration()
    }
    end()
    
    guard !parser.hadError else { return false }
    
    return true
}
