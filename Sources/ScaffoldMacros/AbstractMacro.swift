//
//  AbstractMacro.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/30/25.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that generates a protocol containing all public functions and properties from a class or struct,
/// and creates an extension to conform to that protocol.
///
/// Usage:
/// ```swift
/// @Abstract
/// final class FeatureScaffold {
///     var name: String { "Feature" }
///     let version: Int = 1
///     func dao() -> FeatureDAO { ... }
///     func repository() -> FeatureRepository { ... }
///     private func helperFunction() { ... } // This won't be included
///     private var privateProperty: String = "" // This won't be included
/// }
/// ```
///
/// Or with protocol conformances:
/// ```swift
/// @Abstract(Sendable.self, Hashable.self)
/// final class FeatureScaffold {
///     // ... same as above
/// }
/// ```
///
/// Generates:
/// ```swift
/// protocol AbstractFeatureScaffold: Sendable, Hashable {
///     var name: String { get }
///     var version: Int { get }
///     func dao() -> FeatureDAO
///     func repository() -> FeatureRepository
/// }
/// ```

public enum ProtocolMacroError: Error {
    case notClassOrStruct
}

public struct AbstractMacro: PeerMacro {

    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {

        let classDecl = declaration.as(ClassDeclSyntax.self)
        let structDecl = declaration.as(StructDeclSyntax.self)

        if classDecl == nil && structDecl == nil {
            throw ProtocolMacroError.notClassOrStruct
        }

        let typeName = classDecl?.name.text ?? structDecl?.name.text ?? ""
        let protocolName = "Abstract" + typeName

        let members =
            classDecl?.memberBlock.members ?? structDecl?.memberBlock.members
            ?? []
        let nonPrivateMembers: TypeMembers = extractNonPrivateMembers(members)

        let properties = stringify(nonPrivateMembers.properties)
        let functions = stringify(nonPrivateMembers.functions)

        let genericParameters =
            classDecl?.genericParameterClause?.description ?? structDecl?
            .genericParameterClause?.description ?? ""
        let genericWhereClause =
            classDecl?.genericWhereClause?.description ?? structDecl?
            .genericWhereClause?.description ?? ""
        let associatedTypes = createAssociatedtypes(
            genericParameters,
            whereClause: genericWhereClause
        )

        // Parse protocol conformances from the attribute arguments
        let protocolConformances = extractProtocolConformances(from: node)
        let inheritanceClause =
            protocolConformances.isEmpty
            ? "" : ": \(protocolConformances.joined(separator: ", "))"

        let protocolDecl = ProtocolDeclSyntax(
            name: "\(raw: protocolName)",
            inheritanceClause: inheritanceClause.isEmpty
                ? nil
                : InheritanceClauseSyntax(
                    inheritedTypes: InheritedTypeListSyntax {
                        for (index, protocolName)
                            in protocolConformances.enumerated()
                        {
                            InheritedTypeSyntax(
                                type: IdentifierTypeSyntax(
                                    name: .identifier(protocolName)
                                ),
                                trailingComma: index < protocolConformances
                                    .count - 1 ? .commaToken() : nil
                            )
                        }
                    }
                ),
            memberBlockBuilder: {
                """
                \(raw: associatedTypes)
                \(raw: properties)
                \(raw: functions)
                """
            }
        )
        return [DeclSyntax(protocolDecl)]
    }
}

extension AbstractMacro {

    private struct TypeMembers {
        var properties: [VariableDeclSyntax]
        var functions: [FunctionDeclSyntax]
    }

    private static func extractProtocolConformances(from node: AttributeSyntax)
        -> [String]
    {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self)
        else {
            return []
        }

        var protocols: [String] = []

        for argument in arguments {
            // Handle expressions like "Sendable.self", "Hashable.self", etc.
            if let memberAccess = argument.expression.as(
                MemberAccessExprSyntax.self
            ),
                let base = memberAccess.base?.as(DeclReferenceExprSyntax.self),
                memberAccess.declName.baseName.text == "self"
            {
                protocols.append(base.baseName.text)
            }
            // Handle direct protocol references (if someone just passes the protocol name)
            else if let declRef = argument.expression.as(
                DeclReferenceExprSyntax.self
            ) {
                protocols.append(declRef.baseName.text)
            }
        }

        return protocols
    }

    private static func extractNonPrivateMembers(
        _ members: MemberBlockItemListSyntax
    ) -> TypeMembers {
        var typeMembers = TypeMembers(properties: [], functions: [])
        members.forEach { member in
            if let varDecl = member.decl.as(VariableDeclSyntax.self),
                !varDecl.modifiers.contains(where: {
                    $0.name.text.contains("private")
                })
            {
                typeMembers.properties.append(varDecl)
            }
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
                !funcDecl.modifiers.contains(where: {
                    $0.name.text.contains("private")
                })
            {
                typeMembers.functions.append(funcDecl)
            }
        }
        return typeMembers
    }

    private static func stringify(_ properties: [VariableDeclSyntax]) -> String
    {
        properties.compactMap { varDecl in
            let propertyName =
                varDecl.bindings.first?.pattern.description
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let propertyType =
                varDecl.bindings.first?.typeAnnotation?.type.description
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Any"
            let accessors = varDecl.hasSetter ? "{ get set }" : "{ get }"
            var modifiers: String = ""
            if varDecl.modifiers.contains(where: {
                $0.name.text.contains("static")
            }) {
                modifiers.append("static ")
            }
            return
                "\(modifiers)var \(propertyName): \(propertyType) \(accessors)"
        }.joined(separator: "\n")
    }

    private static func stringify(_ functions: [FunctionDeclSyntax]) -> String {
        functions.compactMap { funcDecl in
            let funcName = funcDecl.name.text
            var generics: String = ""
            if let genericParameter = funcDecl.genericParameterClause?
                .description
            {
                generics = genericParameter
            }
            var whereClause: String = ""
            if let genericWhereClause = funcDecl.genericWhereClause?.description
            {
                whereClause = " \(genericWhereClause)"
            }
            let parameters = funcDecl.signature.parameterClause.parameters.map {
                param in
                var parameterName = param.firstName.text
                if let secondParamName = param.secondName?.text {
                    parameterName += " \(secondParamName)"
                }
                let paramType = param.type.description
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(parameterName): \(paramType)"
            }.joined(separator: ", ")
            let returnType =
                funcDecl.signature.returnClause?.type.description
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let asyncKeyword =
                funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
                ? " async" : ""
            let returnSuffix = returnType.isEmpty ? "" : " -> \(returnType)"
            var modifiers: String = ""
            if funcDecl.modifiers.contains(where: {
                $0.name.text.contains("static")
            }) {
                modifiers.append("static ")
            }
            return
                "\(modifiers)func \(funcName)\(generics)(\(parameters))\(asyncKeyword)\(returnSuffix)\(whereClause)"
        }.joined(separator: "\n")
    }

    private static func createAssociatedtypes(
        _ genericClause: String,
        whereClause: String
    ) -> String {
        guard !genericClause.isEmpty else { return "" }
        return
            genericClause
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: ",")
            .map { genericType in
                var genericType = genericType
                let typeSpecifier =
                    whereClause
                    .replacingOccurrences(of: "where", with: "")
                    .components(separatedBy: ",")
                    .first(where: { typeIdentifier in
                        typeIdentifier
                            .components(separatedBy: ":")
                            .first?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            == genericType
                    })?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if !typeSpecifier.isEmpty {
                    genericType = typeSpecifier
                }
                return "associatedType \(genericType)"
            }.joined(separator: "\n")
    }
}

extension VariableDeclSyntax {
    var hasSetter: Bool {
        switch bindings.first?.accessorBlock?.accessors {
        case .accessors(let accessors):
            return accessors.contains {
                $0.accessorSpecifier.text.contains("set")
            }
        case .getter:
            return false
        case .none:
            return bindingSpecifier.text == "var"
        }
    }
}

//public struct AbstractMacro: PeerMacro {
//
//    // MARK: - PeerMacro Implementation
//
//    public static func expansion(
//        of node: AttributeSyntax,
//        providingPeersOf declaration: some DeclSyntaxProtocol,
//        in context: some MacroExpansionContext
//    ) throws -> [DeclSyntax] {
//
//        // Ensure we're working with a class or struct
//        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self)
//        else { throw AbstractMacroError.invalidType }
//
//        // Get the type name
//        let typeName: String
//        let publicFunctions: [FunctionDeclSyntax]
//        let publicProperties: [VariableDeclSyntax]
//        if let classDecl = declaration.as(ClassDeclSyntax.self) {
//            typeName = classDecl.name.text
//            publicFunctions = extractPublicFunctions(from: classDecl)
//            publicProperties = extractPublicProperties(from: classDecl)
//        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
//            typeName = structDecl.name.text
//            publicFunctions = extractPublicFunctions(from: structDecl)
//            publicProperties = extractPublicProperties(from: structDecl)
//        } else {
//            throw AbstractMacroError.expansionError("Unable to determine type name")
//        }
//
//        // Generate protocol members
//        let protocolMembers = MemberBlockSyntax {
//            // Add properties first
//            for property in publicProperties {
//                generateProtocolProperty(from: property)
//            }
//
//            // Then add functions
//            for function in publicFunctions {
//                generateProtocolFunction(from: function)
//            }
//        }
//
//        // Create the peer protocol
//        let protocolName = "Abstract\(typeName)"
//        let abstractProtocol = ProtocolDeclSyntax(
//            name: .identifier(protocolName),
//            memberBlock: protocolMembers
//        )
//
//        return [DeclSyntax(abstractProtocol)]
//    }
//
//    // MARK: - ExtensionMacro Implementation
//
//    /// Extracts public functions from the declaration, excluding private functions
//    private static func extractPublicFunctions(from declaration: some DeclGroupSyntax) -> [FunctionDeclSyntax] {
//
//        var functions: [FunctionDeclSyntax] = []
//
//        for member in declaration.memberBlock.members {
//            guard let function = member.decl.as(FunctionDeclSyntax.self) else {
//                continue
//            }
//
//            // Skip private functions
//            let hasPrivateModifier = function.modifiers.contains { modifier in
//                modifier.name.tokenKind == .keyword(.private)
//            }
//
//            if hasPrivateModifier {
//                continue
//            }
//
//            functions.append(function)
//        }
//
//        return functions
//    }
//
//    /// Extracts public properties from the declaration, excluding private properties
//    private static func extractPublicProperties(from declaration: some DeclGroupSyntax) -> [VariableDeclSyntax] {
//
//        var properties: [VariableDeclSyntax] = []
//
//        for member in declaration.memberBlock.members {
//            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
//                continue
//            }
//
//            // Skip private properties
//            let hasPrivateModifier = variable.modifiers.contains { modifier in
//                modifier.name.tokenKind == .keyword(.private)
//            }
//
//            if hasPrivateModifier {
//                continue
//            }
//
//            properties.append(variable)
//        }
//
//        return properties
//    }
//
//    /// Generates a protocol function declaration from a concrete function
//    private static func generateProtocolFunction(from function: FunctionDeclSyntax) -> FunctionDeclSyntax {
//        return FunctionDeclSyntax(
//            name: function.name,
//            signature: FunctionSignatureSyntax(
//                parameterClause: function.signature.parameterClause,
//                returnClause: function.signature.returnClause
//            )
//        )
//    }
//
//    /// Generates a protocol property declaration from a concrete property
//    private static func generateProtocolProperty(from variable: VariableDeclSyntax) -> VariableDeclSyntax {
//        return VariableDeclSyntax(
//            bindingSpecifier: .keyword(.var),
//            bindings: PatternBindingListSyntax {
//                for binding in variable.bindings {
//                    PatternBindingSyntax(
//                        pattern: binding.pattern,
//                        typeAnnotation: binding.typeAnnotation,
//                        accessorBlock: AccessorBlockSyntax(
//                            accessors: .getter(CodeBlockItemListSyntax("get"))
//                        )
//                    )
//                }
//            }
//        )
//    }
//}
//
///// Errors that can occur during macro expansion
//enum AbstractMacroError: Error, CustomStringConvertible {
//    case invalidType
//    case expansionError(String)
//
//    var description: String {
//        switch self {
//            case .invalidType: "@Abstract can only be applied to classes & structs"
//            case .expansionError(let error): "Failed to expand @Abstract: \(error)"
//        }
//    }
//}
