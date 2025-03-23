//
//  ContentView.swift
//  QuickEvent
//
//  Created by Idhant Gulati on 3/22/25.
//

import SwiftUI
import SwiftData
import EventKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var eventText: String = ""
    @StateObject private var calendarManager = CalendarManager()

    var body: some View {
        VStack(spacing: 8) {
            // Calendar Events Section
            if calendarManager.isAuthorized {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming Events")
                        .font(.headline)
                        .padding(.horizontal, 8)
                    
                    ForEach(calendarManager.events, id: \.eventIdentifier) { event in
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.system(size: 12))
                                Text(event.startDate, style: .time)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
            } else {
                VStack(spacing: 8) {
                    if let errorMessage = calendarManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    
                    Button("Allow Calendar Access") {
                        Task {
                            await calendarManager.checkAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            
            // Quick Notes Section
            TextField("Add new note...", text: $eventText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 8)
                .onSubmit {
                    if !eventText.isEmpty {
                        addItem(text: eventText)
                        eventText = ""
                    }
                }
            
            List {
                ForEach(items, id: \.id) { item in
                    HStack {
                        Text(item.text ?? "No text")
                        Spacer()
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .frame(width: 250, height: 150)
            
            Divider()
            
            HStack {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 4)
        }
        .frame(width: 250)
    }

    private func addItem(text: String) {
        withAnimation {
            let newItem = Item(timestamp: Date(), text: text)
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
