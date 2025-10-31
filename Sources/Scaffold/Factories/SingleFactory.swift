//
//  SingleFactory.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/29/25.
//

import Foundation

public final class SingleFactory<V: Sendable>: Factory, @unchecked Sendable {

    private let lock = NSLock()
    private var value: V!

    public init() { }

    public func value(_ factory: () -> V) -> V {
        lock.withLock {
            if let value { return value }
            self.value = factory()
            return value
        }
    }
}
