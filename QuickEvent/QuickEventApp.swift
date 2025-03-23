//
//  QuickEventApp.swift
//  QuickEvent
//
//  Created by Idhant Gulati on 3/22/25.
//

import SwiftUI
import SwiftData
import AppKit
import EventKit

@main
struct QuickEventApp: App {
    @State private var statusItem: NSStatusItem?
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var openAIManager = OpenAIManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra("QuickCal", systemImage: "calendar") {
            ContentView()
                .environmentObject(calendarManager)
                .environmentObject(openAIManager)
        }
        .menuBarExtraStyle(.window)
        
        WindowGroup {
            Text("QuickEvent")
                .onAppear {
                    // Hide the main window as we're using this as a menu bar app
                    NSApplication.shared.windows.forEach { window in
                        window.close()
                    }
                    
                    // Check calendar permissions on launch
                    Task {
                        await calendarManager.checkAuthorization()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
