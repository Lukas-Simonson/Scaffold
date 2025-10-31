//
//  Factory.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/29/25.
//

public protocol Factory: Sendable {
    associatedtype Value: Sendable

    func value(_ factory: () -> Value) -> Value
}
