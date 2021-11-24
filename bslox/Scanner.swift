//
//  Scanner.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-05-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

enum TokenType: UInt8 {
    case
    // Single-character tokens.
    leftParen, rightParen, leftBrace, rightBrace,
    comma, dot, minus, plus, semicolon, slash, star,
    
    // One or two character tokens.
    bang, bangEqual,
    equal, equalEqual,
    greater, greaterEqual,
    less, lessEqual,
    
    // Literals.
    identifier, string, number,
    
    // Keywords.
    and, `class`, `else`, `false`, fun, `for`, `if`, `nil`, or,
    print, `return`, `super`, this, `true`, `var`, `while`,
    
    error,
    eof
}

struct Token {
    let type: TokenType
    let text: Substring
    let line: Int
}

struct Scanner {
    private let source: String
    private var start: String.UnicodeScalarIndex
    private var current: String.UnicodeScalarIndex
    private var line: Int
    
    init(_ source: String) {
        self.source = source
        self.start = source.startIndex
        self.current = source.startIndex
        self.line = 1
    }
    
    private var isAtEnd: Bool {
        return current >= source.unicodeScalars.endIndex
    }
    
    private var peek: UnicodeScalar {
        if isAtEnd { return "\0" }
        return source.unicodeScalars[current]
    }
    
    private var peekNext: UnicodeScalar {
        let next = source.unicodeScalars.index(after: current)
        if next >= source.unicodeScalars.endIndex {
            return "\0"
        }
        
        return source.unicodeScalars[next]
    }
    
    var text: Substring { return source[start..<current] }
    
    @discardableResult private mutating func advance() -> UnicodeScalar {
        let result = source.unicodeScalars[current]
        current = source.unicodeScalars.index(after: current)
        return result
    }
    
    private mutating func match(_ expected: UnicodeScalar) -> Bool {
        if isAtEnd { return false }
        guard source.unicodeScalars[current] == expected else { return false }
        current = source.unicodeScalars.index(after: current)
        return true
    }
    
    private mutating func skipWhitespace() {
        while true {
            switch peek {
            case " ": fallthrough
            case "\r": fallthrough
            case "\t":
                advance()
                
            case "\n":
                line += 1
                advance()
                
            case "/" where peekNext == "/":
                while peek != "\n" && !isAtEnd { advance() }
                
            default: return
            }
        }
    }
    
    mutating func scanToken() -> Token {
        skipWhitespace()
        start = current
        
        if isAtEnd { return makeToken(.eof) }
        
        let c = advance()
        
        switch c {
        case "(": return makeToken(.leftParen)
        case ")": return makeToken(.rightParen)
        case "{": return makeToken(.leftBrace)
        case "}": return makeToken(.rightBrace)
        case ";": return makeToken(.semicolon)
        case ",": return makeToken(.comma)
        case ".": return makeToken(.dot)
        case "-": return makeToken(.minus)
        case "+": return makeToken(.plus)
        case "/": return makeToken(.slash)
        case "*": return makeToken(.star)

        case "!":
            return makeToken(match("=") ? .bangEqual : .bang)
        case "=":
            return makeToken(match("=") ? .equalEqual : .equal)
        case "<":
            return makeToken(match("=") ? .lessEqual : .less)
        case ">":
            return makeToken(match("=") ? .greaterEqual : .greater)
        
        case "\"": return string()
            
        case _ where c.isAlpha: return identifier()
        case _ where c.isDigit: return number()
            
        default: break
        }
        
        return errorToken("Unexpected character")
    }
    
    private mutating func string() -> Token {
        while peek != "\"" && !isAtEnd {
            if peek == "\n" { line += 1 }
            advance()
        }
        
        if isAtEnd { return errorToken("Unterminated string.") }
        
        // The closing ".
        advance()
        return makeToken(.string)
    }
    
    private mutating func number() -> Token {
        while peek.isDigit { advance() }
        
        // Look for a fractional part.
        if peek == "." && peekNext.isDigit {
            // Consume the "."
            advance()
            
            while peek.isDigit { advance() }
        }
        
        return makeToken(.number)
    }
    
    private mutating func identifier() -> Token {
        while peek.isAlpha || peek.isDigit { advance() }

        let keywords: [String: TokenType] = [
            "and": .and,
            "class": .class,
            "else": .else,
            "false": .false,
            "for": .for,
            "fun": .fun,
            "if": .if,
            "nil": .nil,
            "or": .or,
            "print": .print,
            "return": .return,
            "super": .super,
            "this": .this,
            "true": .true,
            "var": .var,
            "while": .while
        ]
        
        return makeToken(keywords[String(text)] ?? .identifier)
    }
    
    private func identifierType() -> TokenType {
        
        return .identifier
    }
    
    private func makeToken(_ type: TokenType) -> Token {
        return Token(type: type, text: text, line: line)
    }
    
    private func errorToken(_ message: Substring) -> Token {
        return Token(type: .error, text: message, line: line)
    }
}

private extension UnicodeScalar {
    var isDigit: Bool {
        return self >= "0" && self <= "9"
    }
    
    var isAlpha: Bool {
        return
            (self >= "a" && self <= "z")
                || (self >= "A" && self <= "Z")
                || (self == "_")
    }
}
