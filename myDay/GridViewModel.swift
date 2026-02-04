import Foundation
import SwiftData
import Combine

@MainActor
final class GridViewModel: ObservableObject {
    private let context: ModelContext
    private let calendar: Calendar

    /// Today in the user's current calendar/timezone, normalized to start of day.
    let today: Date

    /// Currently selected month (1...12).
    @Published var selectedMonth: Int

    /// Currently selected year (e.g., 2026).
    @Published var selectedYear: Int

    /// All days in the selected month (each normalized to start of day).
    /// This is derived from `selectedYear` and `selectedMonth` so it always
    /// stays in sync when either of those values change.
    var daysInSelectedMonth: [Date] {
        guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let days: [Date] = range.compactMap { day -> Date? in
            calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day))?.startOfDay
        }
        return days
    }

    convenience init() {
        let schema = Schema([TimeEntry.self])
        let container = try! ModelContainer(for: schema)
        let context = ModelContext(container)
        self.init(context: context)
    }

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar

        let today = Date().startOfDay
        self.today = today
        let comps = calendar.dateComponents([.year, .month], from: today)
        self.selectedYear = comps.year ?? 2000
        self.selectedMonth = comps.month ?? 1
    }

    // MARK: - Month handling

    /// Convenience helpers to adjust the current month from the UI.
    func setMonth(year: Int, month: Int) {
        selectedYear = year
        selectedMonth = month
    }

    func incrementMonth(by offset: Int) {
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)),
              let newDate = calendar.date(byAdding: .month, value: offset, to: date) else { return }
        let comps = calendar.dateComponents([.year, .month], from: newDate)
        selectedYear = comps.year ?? selectedYear
        selectedMonth = comps.month ?? selectedMonth
    }

    // MARK: - Helpers

    // MARK: - Public API used by Views

    /// Returns the persisted entry for a given logical day + hour, if one exists.
    func entry(for date: Date, hour: Int) -> TimeEntry? {
        fetchEntry(for: date.startOfDay, hour: hour)
    }

    /// Sets the activity for a given (date, hour) slot by updating or inserting
    /// a `TimeEntry` in SwiftData, then saving the `ModelContext`.
    func set(category: ActivityCategory, for date: Date, hour: Int) {
        let day = date.startOfDay
        let clampedHour = max(0, min(23, hour))

        if let existing = fetchEntry(for: day, hour: clampedHour) {
            // Update existing slot
            existing.category = category
        } else {
            // No existing entry – create a new one. TimeEntry itself ensures
            // date normalization and a unique (day, hour) key at the model level.
            let new = TimeEntry(date: day, hour: clampedHour, category: category)
            context.insert(new)
        }

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

    // The old 7-day window APIs are no longer used now that the grid is
    // month-based, but are kept here (no-op) in case existing previews or
    // tests still reference them.
    func updateVisibleRange(start: Date, end: Date) {
        // Map any external calls into the current month based on `start`.
        let comps = calendar.dateComponents([.year, .month], from: start.startOfDay)
        selectedYear = comps.year ?? selectedYear
        selectedMonth = comps.month ?? selectedMonth
    }

    func extendRangeIfNeeded(scrolledToTop: Bool) {
        // Interpret extension as paging months up/down.
        incrementMonth(by: scrolledToTop ? -1 : 1)
    }
}
