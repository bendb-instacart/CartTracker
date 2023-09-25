//
//  CartTrackerApp.swift
//  CartTracker
//
//  Created by Ben Bader on 9/25/23.
//

import SwiftUI

@main
struct CartTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
