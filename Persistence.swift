//
//  Persistence.swift
//  BlockBlast
//
//  Core Data stack shared across the app. Inject the container’s view context
//  via SwiftUI’s environment from BlockBlastApp — views below ContentView can
//  read `@Environment(\.managedObjectContext)` when you start persisting data.
//

import CoreData

struct PersistenceController {

    /// Live application stack — reads/writes the SQLite store on disk.
    static let shared = makeShared()

    /// In-memory store for SwiftUI previews and tests (no disk side effects).
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        let context = controller.container.viewContext
        // Seed without the codegen `PersistedScore` class so previews build even
        // before Xcode generates Core Data subclasses from the `.xcdatamodeld`.
        if let entity = NSEntityDescription.entity(forEntityName: "PersistedScore", in: context) {
            let sample = NSManagedObject(entity: entity, insertInto: context)
            sample.setValue(Int32(12_340), forKey: "score")
            sample.setValue(Date(), forKey: "createdAt")
            do {
                try context.save()
            } catch {
                assertionFailure("Preview seed save failed: \(error)")
            }
        }

        return controller
    }()

    let container: NSPersistentContainer

    /// - Parameter inMemory: When `true`, stores entities only in RAM (lost when the process exits).
    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BlockBlast")

        if inMemory {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Missing persistent store description.")
            }
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                // Replace with logging / crash reporting in production if desired.
                fatalError("Unresolved Core Data error \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Saves the view context if there are unsaved changes.
    func saveIfNeeded() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            assertionFailure("Core Data save failed: \(error)")
        }
    }

    private static func makeShared() -> PersistenceController {
        PersistenceController(inMemory: false)
    }
}
