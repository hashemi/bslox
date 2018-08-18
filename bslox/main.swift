//
//  main.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-02-19.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux) || CYGWIN
import Glibc
#endif

private var vm = VM()

func repl() {
    while true {
        print("> ", terminator: "")
        guard let line = readLine() else { return }
        _ = vm.interpret(line)
    }
}

func runFile(_ path: String) {
    let source = readFile(path)
    let result = vm.interpret(source)
    
    switch result {
    case .compileError: exit(65)
    case .runtimeError: exit(70)
    case .ok: break
    }
}

func readFile(_ path: String) -> String {
    guard let file = fopen(path, "rb") else {
        fputs("Could not open file \"\(path)\".", stderr)
        exit(74)
    }
    defer { fclose(file) }
    
    fseek(file, 0, SEEK_END)
    let fileSize = ftell(file)
    rewind(file)
    
    var buffer = [CChar](repeating: 0, count: fileSize + 1)
    let bytesRead = fread(&buffer, 1, fileSize, file)
    
    guard bytesRead == fileSize else {
        fputs("Could not read file \"\(path)\".", stderr)
        exit(74)
    }
    
    buffer[fileSize] = 0
    return String(validatingUTF8: buffer)!
}

switch CommandLine.arguments.count {
case 1: repl()
case 2: runFile(CommandLine.arguments[1])
default:
    fputs("Usage: slox [script]", stderr)
    exit(64)
}

