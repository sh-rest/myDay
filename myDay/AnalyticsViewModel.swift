import Foundation
import Combine
import SwiftData

@MainActor
final class AnalyticsViewModel: ObservableObject {
    enum WeekOverWeekChange {
        case increase
        case decrease
        case noChange
    }

    struct ActivityWeekStats {
        let activity: ActivityCategory
        let currentWeekAverageHoursPerDay: Double
        let previousWeekAverageHoursPerDay: Double
        let change: WeekOverWeekChange
    }

    private let context: ModelContext
    private let referenceDate: Date

    // Exposed properties for views
    @Published private(set) var activityStats: [ActivityCategory: ActivityWeekStats] = [:]
    @Published private(set) var streakCount: Int = 0

    init(context: ModelContext, referenceDate: Date = Date()) {
        self.context = context
        self.referenceDate = referenceDate.startOfDay
        refresh()
    }

    func refresh() {
        // Sliding windows based on the reference date (today):
        // - Current week: today and the previous 6 days (7 days total).
        // - Previous week: days 7–13 days ago (the 7 days immediately before the current window).
        let today = referenceDate.startOfDay

        let currentWeekEnd = today
        let currentWeekStart = today.addingDays(-6)

        let previousWeekEnd = currentWeekStart.addingDays(-1)   // 7 days ago
        let previousWeekStart = previousWeekEnd.addingDays(-6)  // 13 days ago

        // Fetch entries for current and previous sliding weeks
        let currentWeekEntries = fetchEntries(from: currentWeekStart, to: currentWeekEnd)
        let previousWeekEntries = fetchEntries(from: previousWeekStart, to: previousWeekEnd)

        // Aggregate hours per activity (1 TimeEntry == 1 hour)
        let currentTotals = Self.aggregateHoursByActivity(entries: currentWeekEntries)
        let previousTotals = Self.aggregateHoursByActivity(entries: previousWeekEntries)

        var newStats: [ActivityCategory: ActivityWeekStats] = [:]

        for activity in ActivityCategory.allCases {
            let currentTotal = Double(currentTotals[activity] ?? 0)
            let previousTotal = Double(previousTotals[activity] ?? 0)

            let currentAvg = currentTotal / 7.0
            let previousAvg = previousTotal / 7.0

            let change: WeekOverWeekChange
            if abs(currentAvg - previousAvg) < 0.0001 {
                change = .noChange
            } else if currentAvg > previousAvg {
                change = .increase
            } else {
                change = .decrease
            }

            newStats[activity] = ActivityWeekStats(
                activity: activity,
                currentWeekAverageHoursPerDay: currentAvg,
                previousWeekAverageHoursPerDay: previousAvg,
                change: change
            )
        }

        activityStats = newStats

        // Streak calculation (consecutive days up to and including referenceDate with >=1 entry)
        streakCount = Self.computeStreakCount(upTo: referenceDate, context: context)
    }

    // MARK: - Helpers

    private func fetchEntries(from start: Date, to end: Date) -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.date >= start.startOfDay && $0.date <= end.startOfDay }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    private static func aggregateHoursByActivity(entries: [TimeEntry]) -> [ActivityCategory: Int] {
        var result: [ActivityCategory: Int] = [:]
        for entry in entries {
            let category = entry.category
            result[category, default: 0] += 1
        }
        return result
    }

    private static func computeStreakCount(upTo referenceDate: Date, context: ModelContext) -> Int {
        let endDay = referenceDate.startOfDay

        // Fetch all entries up to reference day
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.date <= endDay }
        )

        let entries: [TimeEntry]
        do {
            entries = try context.fetch(descriptor)
        } catch {
            return 0
        }

        // Build a set of days that have at least one entry
        var daysWithEntries = Set<Date>()
        for entry in entries {
            daysWithEntries.insert(entry.date.startOfDay)
        }

        var streak = 0
        var currentDay = endDay

        while daysWithEntries.contains(currentDay) {
            streak += 1
            currentDay = currentDay.addingDays(-1)
        }

        return streak
    }

    private static var mondayFirstCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let day = date.startOfDay
        let weekday = calendar.component(.weekday, from: day)

        // Convert to offset from Monday (1) to Sunday (7)
        let normalizedWeekday = ((weekday - calendar.firstWeekday) + 7) % 7
        let daysFromMonday = normalizedWeekday

        return day.addingDays(-daysFromMonday)
    }
}
