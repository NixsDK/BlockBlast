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
        TabView {
            GameView()
                .tabItem {
                    Label("Play", systemImage: "gamecontroller.fill")
                }

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("ContentView") {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
