//
//  ScaffoldPlugin.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/29/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ScaffoldPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SingleMacro.self,
        SharedMacro.self,
        AbstractMacro.self,
    ]
}
