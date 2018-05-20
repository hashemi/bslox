//
//  Compiler.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-05-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

func compile(_ source: String) {
    var scanner = Scanner(source)
    
    var line = -1
    while true {
        let token = scanner.scanToken()
        if (token.line != line) {
            print("\(token.line)\t \t", terminator: "")
            line = token.line
        } else {
            print("\t|\t", terminator: "")
        }
        print("\(token.type)\t'\(token.text)'")
        
        if token.type == .eof { break }
    }
}
