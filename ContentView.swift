//
//  ContentView.swift
//  BlockBlast
//
//  Root SwiftUI container. Core Data’s managed object context is injected one
//  level up (BlockBlastApp); this view hosts the existing game UI so future
//  tabs, navigation, or settings screens can wrap GameView without touching
//  gameplay code.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        // `managedObjectContext` is injected on `ContentView` from BlockBlastApp
        // and propagates automatically to `GameView` and its descendants.
        GameView()
    }
}

#Preview("ContentView") {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
