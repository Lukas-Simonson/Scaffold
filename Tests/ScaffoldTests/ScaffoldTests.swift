import Foundation
import Testing
import Scaffold

//@Suite("Dependency Injection Factory Tests")
//struct FactoryTests {
//
//    // MARK: - @Single Macro Tests
//    
//    @Test("@Single macro returns same instance")
//    func testSingleMacroReturnsSameInstance() async throws {
//        let module = TestRootModule()
//        
//        // Test that the same instance is returned
//        let db1 = module.db()
//        let db2 = module.db()
//        
//        // Should be the same instance due to singleton behavior
//        #expect(db1 === db2, "@Single macro should return the same instance")
//    }
//    
//    @Test("@Single macro with dependent injection")
//    func testSingleMacroWithDependentInjection() async throws {
//        let module = TestRootModule()
//        
//        // Test with dependent injection
//        let dao1 = module.dao()
//        let dao2 = module.dao()
//        
//        #expect(dao1 === dao2, "@Single macro should return the same instance for dependent objects")
//        
//        // Verify that the injected dependencies are also singletons
//        let db1 = module.db()
//        let dao3 = module.dao()
//        
//        // The database instance used by dao should be the same as the one we get directly
//        #expect(db1 === db1, "Injected database should be the same singleton instance")
//    }
//    
//    @Test("@Single macro thread safety")
//    func testSingleMacroThreadSafety() async throws {
//        let module = TestRootModule()
//        
//        // Test concurrent access to ensure thread safety
//        await withTaskGroup(of: Database.self) { group in
//            var databases: [Database] = []
//            
//            for _ in 0..<10 {
//                group.addTask {
//                    return module.db()
//                }
//            }
//            
//            for await database in group {
//                databases.append(database)
//            }
//            
//            // All instances should be the same
//            let firstDb = databases.first!
//            for db in databases {
//                #expect(firstDb === db, "All database instances should be identical even with concurrent access")
//            }
//        }
//    }
//
//    // MARK: - @Shared Macro Tests
//    
//    @Test("@Shared macro returns same instance")
//    func testSharedMacroReturnsSameInstance() async throws {
//        let module = TestSharedModule()
//        
//        // Test that the same instance is returned
//        let service1 = module.networkService()
//        let service2 = module.networkService()
//        
//        #expect(service1 === service2, "@Shared macro should return the same instance")
//    }
//    
//    @Test("@Shared macro with complex dependencies")
//    func testSharedMacroWithComplexDependencies() async throws {
//        let module = TestSharedModule()
//        
//        // Test repository that depends on both database and network service
//        let repo1 = module.repository()
//        let repo2 = module.repository()
//        
//        #expect(repo1 === repo2, "@Shared macro should return the same repository instance")
//        
//        // Verify that dependencies are also shared
//        let db1 = module.database()
//        let db2 = module.database()
//        let service1 = module.networkService()
//        let service2 = module.networkService()
//        
//        #expect(db1 === db2, "Database should be shared")
//        #expect(service1 === service2, "Network service should be shared")
//    }
//    
//    @Test("@Shared macro initialization only happens once")
//    func testSharedMacroInitializationOnlyOnce() async throws {
//        let module = TestSharedModule()
//        
//        // Get multiple instances
//        let counter1 = module.initializationCounter()
//        let counter2 = module.initializationCounter()
//        let counter3 = module.initializationCounter()
//        
//        #expect(counter1 === counter2, "Should be the same instance")
//        #expect(counter2 === counter3, "Should be the same instance")
//        
//        // The counter should only be incremented once during initialization
//        #expect(counter1.count == 1, "Initialization should only happen once")
//    }
//
//    // MARK: - Mixed @Single and @Shared Tests
//    
//    @Test("Mixed @Single and @Shared dependencies")
//    func testMixedSingleAndSharedDependencies() async throws {
//        let singleModule = TestRootModule()
//        let sharedModule = TestSharedModule()
//        
//        // Get instances from both modules
//        let singleDb = singleModule.db()
//        let sharedDb = sharedModule.database()
//        
//        // These should be different instances since they're from different modules
//        #expect(type(of: singleDb) == type(of: sharedDb), "Both should be the same type")
//        
//        // But within each module, they should maintain singleton behavior
//        let singleDb2 = singleModule.db()
//        let sharedDb2 = sharedModule.database()
//        
//        #expect(singleDb === singleDb2, "Single module should maintain singleton")
//        #expect(sharedDb === sharedDb2, "Shared module should maintain singleton")
//    }
//    
//    @Test("Module isolation")
//    func testModuleIsolation() async throws {
//        let module1 = TestRootModule()
//        let module2 = TestRootModule()
//        
//        // Instances from different module instances should be different
//        let db1 = module1.db()
//        let db2 = module2.db()
//        
//        // These should be different instances since they're from different module instances
//        #expect(db1 !== db2, "Different module instances should create different singletons")
//        
//        // But within the same module, should be the same
//        let db1_again = module1.db()
//        let db2_again = module2.db()
//        
//        #expect(db1 === db1_again, "Same module should return same instance")
//        #expect(db2 === db2_again, "Same module should return same instance")
//    }
//}
//
//// MARK: - Test Protocol and Implementation Classes
//
//protocol Database: AnyObject, Sendable {
//    var id: String { get }
//}
//
//final class GRDBDatabase: Database {
//    let id: String
//    
//    init() {
//        self.id = UUID().uuidString
//    }
//    
//    func setLocation(_ path: String) {
//        // Mock implementation
//    }
//}
//
//protocol FeatureDAO: AnyObject, Sendable {
//    var name: String { get }
//    var database: Database { get }
//}
//
//final class FeatureDAOImpl: FeatureDAO {
//    let name: String
//    let database: Database
//
//    init(from db: Database) {
//        self.database = db
//        self.name = String(Int.random(in: 0...10000000))
//    }
//}
//
//protocol NetworkService: AnyObject, Sendable {
//    var baseURL: String { get }
//}
//
//final class NetworkServiceImpl: NetworkService {
//    let baseURL: String
//    
//    init() {
//        self.baseURL = "https://api.example.com"
//    }
//}
//
//protocol Repository: AnyObject, Sendable {
//    var database: Database { get }
//    var networkService: NetworkService { get }
//}
//
//final class RepositoryImpl: Repository {
//    let database: Database
//    let networkService: NetworkService
//    
//    init(database: Database, networkService: NetworkService) {
//        self.database = database
//        self.networkService = networkService
//    }
//}
//
//final class InitializationCounter: Sendable {
//    let count: Int
//    
//    init() {
//        // Simulate that this gets called during initialization
//        self.count = GlobalCounter.increment()
//    }
//}
//
//// Helper for tracking initialization calls
//final class GlobalCounter {
//    nonisolated(unsafe) private static var _count = 0
//    private static let queue = DispatchQueue(label: "counter")
//    
//    static func increment() -> Int {
//        return queue.sync {
//            _count += 1
//            return _count
//        }
//    }
//    
//    static func reset() {
//        queue.sync {
//            _count = 0
//        }
//    }
//}
//
//// MARK: - Test Modules
//
//@Abstract
//final class TestRootModule: Sendable, AbstractTestRootModule {
//
//    @Single
//    func db() -> Database {
//        GRDBDatabase()
//    }
//
//    @Single
//    func dao() -> FeatureDAO {
//        FeatureDAOImpl(from: db())
//    }
//
//    @Shared
//    func testScaffold() -> TestSharedModule {
//        TestSharedModule()
//    }
//}
//
//final class TestSharedModule: Sendable {
//
//    @Shared
//    func database() -> Database {
//        let database = GRDBDatabase()
//        database.setLocation("/test/database/path")
//        return database
//    }
//    
//    @Shared
//    func networkService() -> NetworkService {
//        NetworkServiceImpl()
//    }
//    
//    @Shared
//    func repository() -> Repository {
//        RepositoryImpl(database: database(), networkService: networkService())
//    }
//    
//    @Shared
//    func initializationCounter() -> InitializationCounter {
//        // Reset counter before creating to ensure clean test
//        GlobalCounter.reset()
//        return InitializationCounter()
//    }
//}
