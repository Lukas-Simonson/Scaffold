//
//  SingleMacro.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/30/25.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SingleMacro: PeerMacro, BodyMacro {
    
    // PeerMacro: Creates the storage property
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Ensure the macro is applied to a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw SingleMacroError.notAFunction
        }
        
        // Get the function name
        let funcName = funcDecl.name.text
        
        // Get the return type
        guard let returnType = funcDecl.signature.returnClause?.type else {
            throw SingleMacroError.missingReturnType
        }
        
        // Create the storage property name
        let storagePropertyName = "_\(funcName)_storage"
        
        // Create the SingleFactory property
        let storageProperty = try VariableDeclSyntax("private let \(raw: storagePropertyName) = SingleFactory<\(returnType)>()")
        
        return [
            DeclSyntax(storageProperty)
        ]
    }
    
    // BodyMacro: Transforms the function body
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        
        // Ensure the macro is applied to a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw SingleMacroError.notAFunction
        }
        
        // Get the function name
        let funcName = funcDecl.name.text
        
        // Get the original function body
        guard let body = funcDecl.body else {
            throw SingleMacroError.missingFunctionBody
        }
        
        // Create the storage property name
        let storagePropertyName = "_\(funcName)_storage"
        
        // Create the new body that calls the storage.value with the original body as a closure
        let newBody = CodeBlockItemSyntax(
            item: .stmt(
                StmtSyntax(
                    ReturnStmtSyntax(
                        returnKeyword: .keyword(.return),
                        expression: ExprSyntax(
                            FunctionCallExprSyntax(
                                calledExpression: MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(baseName: .identifier(storagePropertyName)),
                                    period: .periodToken(),
                                    declName: DeclReferenceExprSyntax(baseName: .identifier("value"))
                                ),
                                leftParen: .leftParenToken(),
                                arguments: LabeledExprListSyntax([
                                    LabeledExprSyntax(
                                        expression: ClosureExprSyntax(
                                            leftBrace: .leftBraceToken(),
                                            statements: body.statements,
                                            rightBrace: .rightBraceToken()
                                        )
                                    )
                                ]),
                                rightParen: .rightParenToken()
                            )
                        )
                    )
                )
            )
        )
        
        return [newBody]
    }
}

enum SingleMacroError: Error, CustomStringConvertible {
    case notAFunction
    case missingReturnType
    case missingFunctionBody
    
    var description: String {
        switch self {
        case .notAFunction:
            return "@Single can only be applied to functions"
        case .missingReturnType:
            return "@Single requires a function with an explicit return type"
        case .missingFunctionBody:
            return "@Single requires a function with a body"
        }
    }
}
