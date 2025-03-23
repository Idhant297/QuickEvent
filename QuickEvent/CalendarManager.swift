import Foundation
import EventKit

@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    init() {
        Task {
            await checkAuthorization()
        }
    }
    
    func checkAuthorization() async {
        if #available(macOS 14.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            switch status {
            case .authorized:
                isAuthorized = true
                await fetchNextEvents()
            case .notDetermined:
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    isAuthorized = granted
                    if granted {
                        await fetchNextEvents()
                    }
                } catch {
                    errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                }
            case .denied, .restricted:
                errorMessage = "Calendar access is denied. Please enable it in System Settings."
                isAuthorized = false
            @unknown default:
                errorMessage = "Unknown calendar authorization status"
                isAuthorized = false
            }
        } else {
            // Fallback for older macOS versions
            let status = EKEventStore.authorizationStatus(for: .event)
            switch status {
            case .authorized:
                isAuthorized = true
                await fetchNextEvents()
            case .notDetermined:
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    Task { @MainActor in
                        self?.isAuthorized = granted
                        if granted {
                            await self?.fetchNextEvents()
                        } else if let error = error {
                            self?.errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                        }
                    }
                }
            case .denied, .restricted:
                errorMessage = "Calendar access is denied. Please enable it in System Settings."
                isAuthorized = false
            @unknown default:
                errorMessage = "Unknown calendar authorization status"
                isAuthorized = false
            }
        }
    }
    
    func fetchNextEvents() async {
        let calendar = Calendar.current
        let now = Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: now)!
        
        let predicate = eventStore.predicateForEvents(withStart: now,
                                                    end: endDate,
                                                    calendars: nil)
        
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
        
        self.events = Array(events)
    }
} 