//
//  SharedMacro.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/30/25.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SharedMacro: PeerMacro, BodyMacro {
    
    // Helper function to extract the concrete return type from the function body
    private static func extractConcreteReturnType(from body: CodeBlockSyntax) throws -> String {
        // First, build a map of variable declarations to their concrete types
        var variableTypes: [String: String] = [:]
        
        // Scan through all statements to find variable declarations
        for statement in body.statements {
            // Check if this statement is a variable declaration
            if let variableDecl = statement.item.as(VariableDeclSyntax.self) {
                // Handle let/var declarations like: let database = GRDBDatabase()
                for binding in variableDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       let initializer = binding.initializer,
                       let concreteType = extractTypeFromExpression(initializer.value) {
                        variableTypes[pattern.identifier.text] = concreteType
                    }
                }
            }
        }
        
        // Now look for the return statement and resolve the type
        for statement in body.statements.reversed() {
            // Check for explicit return statement
            if let returnStmt = statement.item.as(ReturnStmtSyntax.self),
               let returnExpr = returnStmt.expression {
                if let concreteType = resolveTypeFromExpression(returnExpr, variableTypes: variableTypes) {
                    return concreteType
                }
            }
            
            // Check for direct expression (implicit return)
            if let expr = statement.item.as(ExprSyntax.self) {
                if let concreteType = resolveTypeFromExpression(expr, variableTypes: variableTypes) {
                    return concreteType
                }
            }
        }
        
        throw SharedMacroError.couldNotDetermineReturnType
    }
    
    // Helper function to resolve type from expression, using variable type mapping
    private static func resolveTypeFromExpression(_ expr: ExprSyntax, variableTypes: [String: String]) -> String? {
        // First check if this is a variable reference that we know the type of
        if let identifier = expr.as(DeclReferenceExprSyntax.self) {
            let varName = identifier.baseName.text
            if let resolvedType = variableTypes[varName] {
                return resolvedType
            }
        }
        
        // Otherwise, try to extract the type directly from the expression
        return extractTypeFromExpression(expr)
    }
    
    // Helper function to extract type name from various expression types
    private static func extractTypeFromExpression(_ expr: ExprSyntax) -> String? {
        // Handle function calls like GRDBDatabase() or FeatureDAOImpl(from: db())
        if let funcCall = expr.as(FunctionCallExprSyntax.self) {
            if let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self) {
                // Handle cases like SomeType.init() or SomeType.create()
                return memberAccess.base?.description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Handle direct constructor calls like GRDBDatabase()
                let calledExpr = funcCall.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove any generic parameters or parentheses
                let typeName = calledExpr.components(separatedBy: "<").first ?? calledExpr
                return typeName
            }
        }
        
        // Handle direct type references
        if let identifier = expr.as(DeclReferenceExprSyntax.self) {
            return identifier.baseName.text
        }
        
        // Handle member access like Type.someProperty
        if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
            return memberAccess.base?.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    // PeerMacro: Creates the storage property
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw SharedMacroError.onlyApplicableToFunctions
        }
        
        guard let body = funcDecl.body else {
            throw SharedMacroError.functionMustHaveBody
        }
        
        // Extract the concrete type from the function body
        let concreteType = try extractConcreteReturnType(from: body)
        
        let functionName = funcDecl.name.text
        let storagePropertyName = "_\(functionName)_storage"
        
        let storageProperty = try VariableDeclSyntax("private let \(raw: storagePropertyName) = SharedFactory<\(raw: concreteType)>()")
        
        return [DeclSyntax(storageProperty)]
    }

    // BodyMacro: Transforms the function body
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw SharedMacroError.onlyApplicableToFunctions
        }
        
        guard let originalBody = funcDecl.body else {
            throw SharedMacroError.functionMustHaveBody
        }
        
        let functionName = funcDecl.name.text
        let storagePropertyName = "_\(functionName)_storage"
        
        // Create the new body that calls the storage.value with the original body as a closure
        let newBody = CodeBlockItemSyntax(
            item: .expr(ExprSyntax(
                "return \(raw: storagePropertyName).value \(originalBody)"
            ))
        )
        
        return [newBody]
    }
}

enum SharedMacroError: Error, CustomStringConvertible {
    case onlyApplicableToFunctions
    case functionMustHaveBody
    case couldNotDetermineReturnType
    case unsupportedExpressionType
    case noReturnStatementFound
    case invalidVariableDeclaration

    var description: String {
        switch self {
            case .onlyApplicableToFunctions:
                return "@Shared can only be applied to functions"
            case .functionMustHaveBody:
                return "@Shared function must have a body"
            case .couldNotDetermineReturnType:
                return "Could not determine concrete return type from function body"
            case .unsupportedExpressionType:
                return "Unsupported expression type in function body"
            case .noReturnStatementFound:
                return "No valid return statement found in function body"
            case .invalidVariableDeclaration:
                return "Invalid variable declaration found in function body"
        }
    }
}
