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
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var openAIManager: OpenAIManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 4) {
            // Calendar Events Section
            if calendarManager.isAuthorized {
                CalendarEventsView(events: calendarManager.events)
                    .padding(.horizontal, 8)
            } else {
                VStack(spacing: 8) {
                    Text("Calendar access not enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    Text("Enable in Settings")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    showingSettings = true
                }
            }
            
            Divider()
            
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
            .frame(width: 250, height: 100)
            
            Divider()
            
            HStack {
                Text("QuickCal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .popover(isPresented: $showingSettings) {
                    SettingsView(calendarManager: calendarManager)
                }
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
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

struct SettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @EnvironmentObject private var openAIManager: OpenAIManager
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @State private var apiKeySaved: Bool = false
    @State private var testResponse: String?
    @State private var isTestingAPI: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QuickCal Settings")
                .font(.headline)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Calendar Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if calendarManager.isAuthorized {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Calendar access enabled")
                                    .font(.caption)
                            }
                        } else {
                            if let errorMessage = calendarManager.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                    .padding(.bottom, 4)
                            }
                            
                            HStack(spacing: 8) {
                                Button("Allow Calendar Access") {
                                    Task {
                                        print("⚠️ Calendar access button tapped")
                                        await calendarManager.checkAuthorization()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Open System Settings") {
                                    print("⚠️ Opening System Settings")
                                    calendarManager.openSystemSettingsForCalendar()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // OpenAI API Key Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI API Key")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if openAIManager.isApiKeySet {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key configured")
                                    .font(.caption)
                            }
                            
                            HStack {
                                SecureField("API Key", text: .constant(openAIManager.apiKey))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(true)
                                
                                Button(action: {
                                    openAIManager.clearApiKey()
                                    apiKeyInput = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Test API Button
                            HStack {
                                Button("Test API Connection") {
                                    isTestingAPI = true
                                    Task {
                                        testResponse = await openAIManager.testAPI()
                                        isTestingAPI = false
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isTestingAPI)
                                
                                if isTestingAPI {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.leading, 4)
                                }
                            }
                            .padding(.top, 4)
                            
                            // Show API test result if available
                            if let response = testResponse {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Test Result:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(response.prefix(100) + (response.count > 100 ? "..." : ""))
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.top, 4)
                                .transition(.opacity)
                            }
                        } else {
                            if let errorMessage = openAIManager.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                    .padding(.bottom, 4)
                            }
                            
                            HStack {
                                if showAPIKey {
                                    TextField("Enter OpenAI API Key", text: $apiKeyInput)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                } else {
                                    SecureField("Enter OpenAI API Key", text: $apiKeyInput)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("API keys start with 'sk-'")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button("Save API Key") {
                                let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedKey.isEmpty {
                                    openAIManager.saveApiKey(trimmedKey)
                                    apiKeySaved = true
                                    
                                    // Hide saved confirmation after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        apiKeySaved = false
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            if apiKeySaved {
                                Text("API key saved successfully!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 300)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 320, height: 400)
        .onAppear {
            apiKeyInput = openAIManager.apiKey
        }
    }
}

struct CalendarEventsView: View {
    let events: [Date: [CalendarEvent]]
    
    var sortedDays: [(date: Date, events: [CalendarEvent])] {
        let sortedKeys = events.keys.sorted()
        return sortedKeys.compactMap { date in
            guard let eventsForDay = events[date] else { return nil }
            return (date: date, events: eventsForDay)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedDays.prefix(3), id: \.date) { day in
                DayEventsView(date: day.date, events: day.events)
            }
        }
    }
}

struct DayEventsView: View {
    let date: Date
    let events: [CalendarEvent]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate)
                .font(.headline)
                .foregroundColor(.secondary)
            
            ForEach(events.prefix(5), id: \.id) { event in
                EventRowView(event: event)
            }
        }
    }
}

struct EventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Text(event.timeString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .leading)
            
            Text("·")
                .foregroundColor(.secondary)
            
            Text(event.title)
                .font(.system(size: 14))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.2))
                .padding(.horizontal, -4)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environmentObject(CalendarManager())
        .environmentObject(OpenAIManager())
}
