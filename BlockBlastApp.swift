//
//  BlockBlastApp.swift
//  BlockBlast
//
//  App entry point. Boots Firebase before any view appears so the
//  FirebaseManager singleton can sign the user in anonymously on first launch.
//

import SwiftUI
import CoreData
import FirebaseCore

@main
struct BlockBlastApp: App {

    // We use an AppDelegate adaptor purely to call FirebaseApp.configure() at
    // the earliest legal moment in the lifecycle. SwiftUI's App protocol does
    // not give us a guaranteed pre-view hook, so this remains the canonical
    // way to bootstrap Firebase on iOS.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                // Anonymous sign-in is kicked off as soon as the root view is
                // installed. The call is idempotent — FirebaseManager will
                // short-circuit if the user is already authenticated.
                .task {
                    await FirebaseManager.shared.signInAnonymouslyIfNeeded()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
