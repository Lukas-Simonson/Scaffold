//
//  Macros.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/29/25.
//

/// A macro that transforms a function into a singleton factory pattern.
///
/// The `@Single` macro transforms a function that returns a dependency into
/// a function that uses a `SingleFactory` to ensure the dependency is created
/// only once and cached for subsequent calls.
///
/// ## Thread Safety
///
/// The generated `SingleFactory` instances are thread-safe and use locking
/// to ensure the factory closure is only called once, even in concurrent scenarios.
///
/// ## Requirements
///
/// - Must be applied to a function with an explicit return type
/// - The function must have a body (implementation)
/// - The return type must conform to `Sendable`
///
/// ## Expansion Example
///
/// ```swift
/// class RootScaffold {
///     @Single
///     func database() -> Database {
///         GRDBDatabase()
///     }
///
///     @Single
///     func userDAO() -> UserDAO {
///         UserDAOImpl(database: database())
///     }
/// }
/// ```
///
/// Expands to:
///
/// ```swift
/// class RootScaffold {
///     func database() -> Database {
///         return _database_storage.value {
///             GRDBDatabase()
///         }
///     }
///
///     private let _database_storage = SingleFactory<Database>()
///
///     func userDAO() -> UserDAO {
///         return _userDAO_storage.value {
///             UserDAOImpl(database: database())
///         }
///     }
///
///     private let _userDAO_storage = SingleFactory<UserDAO>()
/// }
/// ```
@attached(peer, names: arbitrary)
@attached(body)
public macro Single() = #externalMacro(module: "ScaffoldMacros", type: "SingleMacro")


/// A macro that transforms a function into a shared factory pattern.
///
/// The `@Shared` macro transforms a function that returns a dependency into
/// a function that uses a `SharedFactory` to manage the dependency's lifecycle.
/// Unlike `@Single`, shared dependencies use weak references and are automatically
/// discarded when there are no strong references to the created dependency.
///
/// ## Memory Management
///
/// The `SharedFactory` holds only a weak reference to the created dependency.
/// When all strong references to the dependency are released, it will be
/// deallocated and the next call to the factory function will create a new instance.
///
/// ## Use Cases
///
/// - Dependencies that should be shared while in use but cleaned up when unused
/// - Resources with natural reference-counting lifecycles
/// - Components that can be safely recreated when needed
/// - Avoiding memory leaks from long-lived singleton dependencies
///
/// ## Requirements
///
/// - Must be applied to a function with an explicit return type
/// - The function must have a body (implementation)
/// - The return type must conform to `Sendable`
/// - The return type must be a reference type (class or actor) to support weak references
///
/// ## Example
///
/// ```swift
/// class NetworkScaffold {
///     @Shared
///     func apiClient() -> APIClient {
///         URLSessionAPIClient()
///     }
///
///     @Shared
///     func userService() -> UserService {
///         UserServiceImpl(client: apiClient())
///     }
/// }
/// ```
/// Expands to:
///
/// ```swift
/// class NetworkScaffold {
///
///     func apiClient() -> APIClient {
///         return _apiClient_storage.value {
///             URLSessionAPIClient()
///         }
///     }
///
///     private let _apiClient_storage = SharedFactory<URLSessionAPIClient>()
///
///     func userService() -> UserService {
///         _userService_storage.value {
///             UserServiceImpl(client: apiClient())
///         }
///     }
///
///     private let _userService_storage = SharedFactory<UserServiceImpl>()
/// }
@attached(peer, names: arbitrary)
@attached(body)
public macro Shared() = #externalMacro(module: "ScaffoldMacros", type: "SharedMacro")


/// A macro that generates a protocol containing all public functions from a class or struct.
///
/// The `@Abstract` macro analyzes the attached class or struct and creates a companion
/// protocol that declares all public / internal members. This enables easier testing, mocking,
/// and dependency injection by providing a protocol interface for your concrete types.
///
/// ## Generated Protocol
///
/// The macro creates a protocol with the name `Abstract{TypeName}` where `{TypeName}`
/// is the name of the class or struct the macro is applied to. The protocol contains
/// stubs for all public / internal members in the original type.
///
/// ## ⚠️ Manual Conformance Required
///
/// **Important**: The macro only generates the protocol declaration. You must manually
/// add conformance to the generated protocol in your type declaration. The generated
/// protocol will always be named `Abstract` + your type name.
///
/// ## Use Cases
///
/// - **Dependency Injection**: Create protocols for your dependency containers
/// - **Testing**: Mock concrete dependencies by conforming test doubles to the generated protocol
/// - **Interface Segregation**: Extract clean interfaces from implementation classes
///
/// ## Requirements
///
/// - Must be applied to a class or struct
/// - The type should have public functions to generate meaningful protocol
/// - **You must manually add the protocol conformance to your type**
///
/// ## Example
///
/// Notice in the example how the `UserScaffold` class conforms to `AbstractUserScaffold`
/// **Without manual conformance, your type will NOT implement the generated protocol.**
///
/// ```swift
/// @Abstract
/// final class UserScaffold: AbstractUserScaffold {
///     func userService() -> UserService {
///         UserServiceImpl()
///     }
///     
///     func userRepository() -> UserRepository {
///         UserRepositoryImpl(database: database())
///     }
///     
///     private func helperMethod() -> String {
///         "This won't be included in the protocol"
///     }
/// }
/// ```
///
/// ** The macro generates this protocol**
/// ```swift
/// protocol AbstractUserScaffold {
///     func userService() -> UserService
///     func userRepository() -> UserRepository
/// }
/// ```
@attached(peer, names: prefixed(Abstract))
public macro Abstract(_ conforming: Any.Type...) = #externalMacro(module: "ScaffoldMacros", type: "AbstractMacro")
