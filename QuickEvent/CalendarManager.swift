import Foundation
import EventKit
import AppKit

struct CalendarEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendar: EKCalendar
    let isAllDay: Bool
    
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.calendar = ekEvent.calendar
        self.isAllDay = ekEvent.isAllDay
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
}

@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [Date: [CalendarEvent]] = [:]
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    init() {
        Task {
            await checkAuthorization()
        }
    }
    
    func checkAuthorization() async {
        print("⚠️ Checking calendar authorization...")
        
        if #available(macOS 14.0, *) {
            print("⚠️ Using macOS 14+ authorization flow")
            let status = EKEventStore.authorizationStatus(for: .event)
            print("⚠️ Current authorization status: \(status)")
            
            switch status {
            case .authorized:
                print("⚠️ Calendar already authorized")
                isAuthorized = true
                await fetchNextEvents()
            case .notDetermined:
                print("⚠️ Authorization not determined, requesting access...")
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    print("⚠️ Access request result: \(granted)")
                    isAuthorized = granted
                    if granted {
                        await fetchNextEvents()
                    } else {
                        errorMessage = "Calendar access was denied. Please enable it in System Settings."
                    }
                } catch {
                    print("⚠️ Error requesting calendar access: \(error.localizedDescription)")
                    errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                }
            case .denied, .restricted:
                print("⚠️ Calendar access denied or restricted")
                errorMessage = "Calendar access is denied. Please enable it in System Settings."
                isAuthorized = false
            case .fullAccess:
                print("⚠️ Full calendar access")
                isAuthorized = true
                await fetchNextEvents()
            @unknown default:
                print("⚠️ Unknown authorization status")
                errorMessage = "Unknown calendar authorization status"
                isAuthorized = false
            }
        } else {
            // Fallback for older macOS versions
            print("⚠️ Using pre-macOS 14 authorization flow")
            let status = EKEventStore.authorizationStatus(for: .event)
            print("⚠️ Current authorization status: \(status)")
            
            switch status {
            case .authorized:
                print("⚠️ Calendar already authorized")
                isAuthorized = true
                await fetchNextEvents()
            case .notDetermined:
                print("⚠️ Authorization not determined, requesting access...")
                // Use completion handler API for older macOS
                let result = await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { accessGranted, error in
                        if let error = error {
                            print("⚠️ Error requesting access: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: accessGranted)
                    }
                }
                
                print("⚠️ Access request result: \(result)")
                isAuthorized = result
                if result {
                    await fetchNextEvents()
                } else {
                    errorMessage = "Calendar access was denied. Please enable it in System Settings."
                }
            case .denied, .restricted:
                print("⚠️ Calendar access denied or restricted")
                errorMessage = "Calendar access is denied. Please enable it in System Settings."
                isAuthorized = false
            @unknown default:
                print("⚠️ Unknown authorization status")
                errorMessage = "Unknown calendar authorization status"
                isAuthorized = false
            }
        }
    }
    
    // Opens the System Settings panel for Calendar access
    func openSystemSettingsForCalendar() {
        print("⚠️ Opening System Settings for Calendar access")
        
        if #available(macOS 13.0, *) {
            // For macOS 13 and later (Ventura+)
            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            } else {
                print("⚠️ Failed to create URL for System Settings")
                
                // Fallback to Security & Privacy
                openSecurityAndPrivacy()
            }
        } else {
            // For macOS 12 and earlier
            openSecurityAndPrivacy()
        }
    }
    
    private func openSecurityAndPrivacy() {
        // Legacy approach for older macOS versions
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            print("⚠️ Failed to open System Preferences")
        }
    }
    
    func fetchNextEvents() async {
        let calendar = Calendar.current
        let now = Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: now)!
        
        let predicate = eventStore.predicateForEvents(withStart: now,
                                                    end: endDate,
                                                    calendars: nil)
        
        let ekEvents = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
        
        // Group events by day
        var groupedEvents: [Date: [CalendarEvent]] = [:]
        
        for ekEvent in ekEvents {
            // Safely unwrap the startDate, which is actually optional in EKEvent
            guard let startDate = ekEvent.startDate else { continue }
            let dayStart = calendar.startOfDay(for: startDate)
            
            let event = CalendarEvent(from: ekEvent)
            
            if groupedEvents[dayStart] == nil {
                groupedEvents[dayStart] = []
            }
            
            groupedEvents[dayStart]?.append(event)
        }
        
        self.events = groupedEvents
    }
} 