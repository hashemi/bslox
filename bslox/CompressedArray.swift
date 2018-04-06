//
//  CompressedArray.swift
//  bslox
//
//  Created by Ahmad Alhashemi on 2018-02-26.
//  Copyright © 2018 Ahmad Alhashemi. All rights reserved.
//

struct CompressedArray<Element: Equatable> {
    // upto is an inclusive upper bound on the range of indices containing Element
    private var storage: [(upto: Int, element: Element)] = []
    
    var count: Int {
        if let lastIdx = storage.last?.upto {
            return lastIdx + 1
        } else {
            return 0
        }
    }
    
    mutating func append(_ newElement: Element) {
        if storage.last?.element != newElement {
            storage.append((upto: count, element: newElement))
        } else {
            storage[storage.count - 1].upto += 1
        }
    }
    
    subscript(index: Int) -> Element {
        get {
            // FIXME: make this a binary search since storage is always ordered by `upto`
            var j = 0
            while storage[j].upto < index { j += 1 }
            return storage[j].element
        }
    }
}
