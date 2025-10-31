//
//  SharedFactory.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/29/25.
//

import Foundation

public final class SharedFactory<V: AnyObject>: Factory, @unchecked Sendable {

    private var lock = NSLock()
    private weak var shared: V? = nil

    public init() { }

    public func value(_ factory: () -> V) -> V {
        lock.withLock {
            if let shared { return shared }

            let value = factory()
            shared = value
            return value
        }
    }
}
