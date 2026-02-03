import Foundation
import SwiftData
import Combine

@MainActor
final class GridViewModel: ObservableObject {
    private let context: ModelContext

    // Visible window defaults to 7 days centered around today
    @Published var visibleStartDate: Date
    @Published var visibleEndDate: Date

    // Cache for entries keyed by (day, hour)
    private var cache: [String: TimeEntry] = [:]

    init(context: ModelContext) {
        self.context = context
        let today = Date().startOfDay
        self.visibleStartDate = today.addingDays(-3)
        self.visibleEndDate = today.addingDays(3)
        preloadEntries()
    }

    // MARK: - Helpers
    func datesInRange(start: Date, end: Date) -> [Date] {
        var dates: [Date] = []
        var d = start.startOfDay
        while d <= end.startOfDay {
            dates.append(d)
            d = d.addingDays(1)
        }
        return dates
    }

    private func key(day: Date, hour: Int) -> String {
        "\(day.timeIntervalSince1970)-\(hour)"
    }

    private func preloadEntries() {
        let start = visibleStartDate.startOfDay
        let end = visibleEndDate.startOfDay
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: []
        )
        do {
            let items = try context.fetch(descriptor)
            cache.removeAll(keepingCapacity: true)
            for item in items {
                cache[key(day: item.date, hour: item.hour)] = item
            }
        } catch {
            // ignore errors for MVP
        }
    }

    // MARK: - Public API used by Views
    func entry(for date: Date, hour: Int) -> TimeEntry? {
        cache[key(day: date.startOfDay, hour: hour)]
    }

    func set(category: ActivityCategory, for date: Date, hour: Int) {
        let day = date.startOfDay
        let clampedHour = max(0, min(23, hour))
        let k = key(day: day, hour: clampedHour)

        // 1) Prefer in-memory cache if present.
        if let existing = cache[k] {
            existing.category = category
            try? context.save()
            objectWillChange.send()
            return
        }

        // 2) Fallback: fetch from the persistent store in case the cache
        //    is stale or missing this particular (day, hour) entry.
        if let persisted = fetchEntry(for: day, hour: clampedHour) {
            persisted.category = category
            cache[k] = persisted
            try? context.save()
            objectWillChange.send()
            return
        }

        // 3) No existing entry – create a new one. TimeEntry itself ensures
        //    date normalization and a unique (day, hour) key at the model level.
        let new = TimeEntry(date: day, hour: clampedHour, category: category)
        context.insert(new)
        cache[k] = new

        // In case of a rare race that violates the unique constraint,
        // SwiftData will throw here; for the MVP we ignore the error.
        try? context.save()
        objectWillChange.send()
    }

    /// Fetches a single TimeEntry for the given logical day + hour.
    private func fetchEntry(for day: Date, hour: Int) -> TimeEntry? {
        var descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.date == day.startOfDay && $0.hour == hour }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    func updateVisibleRange(start: Date, end: Date) {
        visibleStartDate = start.startOfDay
        visibleEndDate = end.startOfDay
        preloadEntries()
        objectWillChange.send()
    }

    func extendRangeIfNeeded(scrolledToTop: Bool) {
        if scrolledToTop {
            visibleStartDate = visibleStartDate.addingDays(-7)
        } else {
            visibleEndDate = visibleEndDate.addingDays(7)
        }
        preloadEntries()
        objectWillChange.send()
    }
}
