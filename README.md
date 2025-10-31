# Scaffold

A Swift macro-based dependency injection framework that provides elegant, type-safe dependency management through compile-time code generation.

## Features

- **Scaffold Pattern**: Organize your dependencies into modular, composable scaffolds
- **Lifecycle Management**: Built-in singleton (`@Single`) and shared (`@Shared`) dependency lifecycles
- **Protocol Generation**: Automatically generate protocols from your concrete dependencies & scaffolds using `@Abstract`
- **Thread-Safe**: All dependency factories are thread-safe by default
- **Compile-Time**: Zero runtime overhead through Swift macros
- **Type-Safe**: Full compile-time type checking and inference

## Requirements

- iOS 17.0+ / macOS 10.15+
- Swift 6.2+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add Scaffold to your project through Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/Lukas-Simonson/Scaffold`
3. Select the version and add to your target

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/youruser/Scaffold", from: "1.0.0")
]
```

## Quick Start

### 1. Define Your Dependencies

It is common practice with DI to define a protocol representation of your dependencies and then refer to that type to make your dependencies easily swappable.
Though you can still do that, Scaffold includes the `@Abstract` macro to generate that protocol for you based on the non-private members of your class or struct.
This makes it incredibly quick and easy to define your dependencies!

To use the `@Abstract` macro, you attach the macro to the struct / class you want to generate a protocol for. You then **MUST** conform to that protocol if you want the benefits
of using the macro. The generated protocol will **ALWAYS** be `AbstractNameOfType`.

```swift
@Abstract
struct AuthDAO: AbstractAuthDAO {
    private let db: Database
    
    var token: String = "some token"
    
    init(db: Database) {
        self.db = db
    }
    
    func create(_ user: User) {
        // Implementation
    }
    
    func read(with id: UUID) -> User {
        // Implementation
    }
    
    private func getContext() -> Database.Context {
        // Implementation
    }
}
```
The `@Abstract` macro would then create your dependency protocol for you. Creating a protocol that looks like this for the prior example:

```swift
protocol AbstractAuthDAO {
    var token: String { get set }
    func create(_ user: User)
    func read(with id: UUID) -> User
}
```

### 2. Create Your Scaffolds

Scaffold is built with a hierarchal structure in mind. Though you can use it however you want. The general idea is to have many smaller scaffolds that stem from each other.
Dependencies are scoped to the scaffold they are created in, so typically you want to enforce a single `Root` scaffold, then have all of your dependencies and child scaffolds branch off from the root.
Because of their nature scaffolds are typically defined as classes, though depending on your structure structs may work as well.

```swift
@Abstract(Sendable.self)
final class AppScaffold: AbstractAppScaffold {
    
}

@Abstract
struct AuthScaffold: AbstractAuthScaffold {
    
}
``` 

Dependencies can be added to the scaffolds by using functions that define how to create instances of your dependencies. 
You can control the lifecycle of these dependencies by using the `@Single` & `@Shared` macros.

- `@Single`: Creates a singleton instance of the dependency scoped to the instance of the scaffold it is defined in.
- `@Shared`: Creates a shared instance of the dependency scoped to the instance of the scaffold it is defined in. The shared instance **MUST** be a class or actor as a weak reference is held on the dependency. Once no more strong references are held on the dependency, it is discarded, and a new instance will be created on the next access.

You can also omit any extra macro on the function to have a new instance of the dependency created each time it is read, or to define your own factory methods.

```swift
@Abstract(Sendable.self)
final class AppScaffold: AbstractAppScaffold {
    @Single 
    func database() -> Database {
        let myDatabase = Database()
        myDatabase.setLocation("/location/to/database.sqlite")
        return myDatabase
    }
}
```

When you need to share dependencies between scaffolds, the hierarchy comes into play. You can define scaffolds as dependencies in other scaffolds, this allows you to pass down other dependencies.

```swift
@Abstract(Sendable.self)
final class AppScaffold: AbstractAppScaffold {
    @Single 
    func database() -> Database { /* ... */ }
    
    // Creates child scaffold as a dependency
    // These can still be scoped, but as AuthScaffold is a struct, not much would happen if it was.
    func authScaffold() -> AbstractAuthScaffold {
        AuthScaffold(self)
    }
}

@Abstract
struct AuthScaffold: AbstractAuthScaffold {
    private let parent: AbstractAppScaffold
    
    init(_ parent: AbstractAppScaffold) {
        self.parent = parent
    }
    
    // Unique Instance Creation
    func authDAO() -> AbstractAuthDAO {
        AuthDAO(db: parent.database())
    }
    
    @Shared
    func authRepository() -> AbstractAuthRepository {
        // Dependencies can rely on each other.
        AuthRepository(dao: authDAO())
    }
}
```

### 3. Use your Dependencies

Scaffold primarily focuses on creating the containers for your DI setup, but doesn't provide a default dependency container. Instead allowing you to change your methods based on context.

If you want to follow a simple DI setup, you can create a singleton instance of your "root" scaffold, then traverse the hierarchy anytime you need a dependency.

```swift
extension AppScaffold {
    static let shared = AppScaffold()
}

class AuthVM {

    let repository: AuthRepository

    // Passing Singleton instance as default value of init, so that the scaffold can be easily swapped out for testing.
    init(_ app: AbstractAuthScaffold = AppScaffold.shared) {
        self.repository = app.authScaffold().authRepository()
    }
}
```

You can also set it up in a dynamic way based on the context of your application, in SwiftUI you may decide to use the Environment to pass around your various scaffolds.

```swift
extension EnvironmentValues {
    @Entry var appScaffold: AbstractAppScaffold!
}

// in App file

NavigationStack {
    // Some Views...
}
.environment(\.appScaffold, AppScaffold())

// Access through the environment

struct HomeScreen: View {
    @Environment(\.appScaffold) private var app
    
    var body: some View {
        ScrollView {
            // Some really cool screen.
        }
        .navigationDestination(for: Auth.self) { _ in
            AuthScreen(authScaffold: app.authScaffold())
        }
    }
}
```

Or any other way you can think to implement it.

## Macros Reference

### `@Abstract`

Generates a protocol containing all public functions and properties from your class or struct:

```swift
@Abstract
final class FeatureScaffold: AbstractFeatureScaffold {
    func repository() -> Repository { ... }
    func service() -> Service { ... }
    private func helper() { ... } // Not included in protocol
}

// Generates:
protocol AbstractFeatureScaffold {
    func repository() -> Repository
    func service() -> Service
}
```

#### With Protocol Conformances

```swift
@Abstract(Sendable.self, Equatable.self)
struct AuthHandler: AbstractAuthHandler {
    // Your implementation
}

// Generates:
protocol AbstractAuthHandler: Sendable, Equatable {
    // Protocol methods
}
```

### `@Single`

Creates a singleton factory - the dependency is created once and cached:

```swift
@Single
func expensiveResource() -> ExpensiveResource {
    ExpensiveResource() // Called only once
}
```

**Thread Safety**: All `@Single` factories are thread-safe and use locking to ensure the factory closure is called exactly once.

**Requirements**:
- Must be applied to a function with an explicit return type
- Return type must conform to `Sendable`
- Function must have a body implementation

### `@Shared`

Creates a shared factory - dependencies are reused while referenced, cleaned up when unused:

```swift
@Shared
func cacheService() -> CacheService {
    CacheService() // Created on first access, reused while referenced
}
```

**Memory Management**: Uses weak references internally. When all strong references to the dependency are released, it will be deallocated and recreated on next access.

**Requirements**:
- Must be applied to a function with an explicit return type
- Return type must be a reference type (class or actor)
- Return type must conform to `Sendable`

## Architecture Patterns

### Modular Scaffolds

Organize related dependencies into focused scaffolds:

```swift
@Abstract(Sendable.self)
final class NetworkScaffold: AbstractNetworkScaffold {
    @Single
    func httpClient() -> HTTPClient {
        URLSessionHTTPClient()
    }
    
    @Single
    func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@Abstract(Sendable.self)
final class DataScaffold: AbstractDataScaffold {
    private let network: AbstractNetworkScaffold
    
    init(network: AbstractNetworkScaffold) {
        self.network = network
    }
    
    @Single
    func database() -> DatabaseProtocol {
        SQLiteDatabase()
    }
    
    @Shared
    func userRepository() -> UserRepository {
        UserRepository(
            database: database(),
            httpClient: network.httpClient(),
            decoder: network.jsonDecoder()
        )
    }
}
```

### Root Application Scaffold

Create a root scaffold that composes your application's dependency graph:

```swift
@Abstract(Sendable.self)
final class RootScaffold: AbstractRootScaffold {
    
    @Shared
    func networkScaffold() -> AbstractNetworkScaffold {
        NetworkScaffold()
    }
    
    @Shared
    func dataScaffold() -> AbstractDataScaffold {
        DataScaffold(network: networkScaffold())
    }
    
    @Shared
    func userService() -> UserService {
        UserService(repository: dataScaffold().userRepository())
    }
}
```

## Testing

The `@Abstract` macro makes testing straightforward by generating protocols for your scaffolds:

```swift
import Testing
@testable import YourApp

// Create a mock scaffold
final class MockAppScaffold: AbstractAppScaffold {
    private let mockDatabase: DatabaseProtocol
    
    init(database: DatabaseProtocol = MockDatabase()) {
        self.mockDatabase = database
    }
    
    func database() -> DatabaseProtocol {
        mockDatabase
    }
    
    func userService() -> UserService {
        UserService(database: database())
    }
}

@Test("User service saves users correctly")
func testUserServiceSave() async throws {
    let mockDB = MockDatabase()
    let scaffold = MockAppScaffold(database: mockDB)
    let userService = scaffold.userService()
    
    let user = User(id: UUID(), name: "Test User")
    try await userService.save(user)
    
    #expect(mockDB.savedUsers.contains { $0.id == user.id })
}
```

## Performance Considerations

### Memory Management

- **`@Single`**: Holds strong references - use for expensive resources that should live for the scaffolds lifetime
- **`@Shared`**: Uses weak references - automatically cleans up unused dependencies

### Thread Safety

All dependency factories are thread-safe by default. No additional synchronization is needed when accessing dependencies from multiple threads.

### Compile-Time Optimization

Scaffold uses Swift macros for zero-runtime overhead. All dependency wiring is resolved at compile-time.

## Advanced Usage

### Custom Factory Patterns

You can combine Scaffold with custom factory patterns:

```swift
@Abstract
final class CustomScaffold: AbstractCustomScaffold {
    
    @Single
    func configurationManager() -> ConfigurationManager {
        ConfigurationManager(environment: .production)
    }
    
    // Custom factory method without macro
    func environmentSpecificService() -> EnvironmentService {
        switch configurationManager().environment {
        case .development:
            return DevelopmentService()
        case .staging:
            return StagingService()
        case .production:
            return ProductionService()
        }
    }
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related Resources

- [Swift Macros Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [Dependency Injection Patterns](https://developer.apple.com/documentation/swift/adoptingasynchronousfunctions)
- [Thread Safety in Swift](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
