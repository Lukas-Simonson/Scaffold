//
//  Example.swift
//  Scaffold
//
//  Created by Lukas Simonson on 10/30/25.
//

import Foundation

// Backing
struct User {
    let id: UUID
}

// Dependencies

// You can use @Abstract, but it is not a requirement.
protocol DatabaseProtocol: Sendable {

}

final class Database: DatabaseProtocol {
    let location: String

    init(location: String) {
        self.location = location
    }
}

@Abstract
struct UserDAO: AbstractUserDAO {
    private var db: DatabaseProtocol

    init(_ db: DatabaseProtocol) {
        self.db = db
    }

    func create(_ user: User) {
        /* Implementation */
    }
}

// Scaffolds / Modules

@Abstract(Sendable.self)
final class AppScaffold: AbstractAppScaffold {

    @Single // A singleton shared for all accesses from this instance.
    func database() -> DatabaseProtocol {
        Database(location: "/some/database/location")
    }

    @Shared // A single instance is shared from this instance, when no strong references are left, that instance is discarded.
    func authScaffold() -> AbstractAuthScaffold {
        AuthScaffold(app: self)
    }
}

@Abstract(Sendable.self)
final class AuthScaffold: AbstractAuthScaffold {
    private let app: AbstractAppScaffold

    init(app: AbstractAppScaffold) {
        self.app = app
    }

    // Unique Factory, new instance created each time.
    func dao() -> AbstractUserDAO {
        UserDAO(app.database())
    }
}
