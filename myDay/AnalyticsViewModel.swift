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

    /// Per-day totals for a single activity, used for trend charts.
    struct DailyActivityTotal: Identifiable {
        let date: Date
        let hours: Int

        var id: Date { date }
    }

    struct ActivityDetailStats {
        let totalHours: Int
        let avgHoursPerDay: Double
        let activeDays: Int
        let frequencyPercent: Double
        let peakHourOfDay: Int?
        let peakDayOfWeek: String?
        let longestStreak: Int
    }

    struct SleepStats {
        let avgHoursPerNight: Double
        let avgBedtimeHour: Double
        let avgWakeHour: Double
        let lateNightPercent: Double
    }

    struct WorkStats {
        let weekdayAvgHours: Double
        let weekendAvgHours: Double
        let mostProductiveDayOfWeek: String?
    }

    struct ExerciseStats {
        let avgHoursOnActiveDays: Double
        let lateExercisePercent: Double
    }

    private let context: ModelContext
    private let referenceDate: Date

    // Exposed properties for views
    @Published private(set) var activityStats: [ActivityCategory: ActivityWeekStats] = [:]
    @Published private(set) var streakCount: Int = 0
    private var cachedAllEntries: [TimeEntry]?

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

        // Invalidate cached all-entries so detail stats are recomputed fresh
        cachedAllEntries = nil
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

    func yearlyTotals(for activity: ActivityCategory) -> [DailyActivityTotal] {
        let end = referenceDate.startOfDay
        let start = end.addingDays(-364)
        return dailyTotals(for: activity, in: DateInterval(start: start, end: end))
    }

    /// Returns daily totals (in hours) for a given activity over the supplied
    /// date interval. The interval is interpreted in terms of logical days
    /// [start.startOfDay, end.startOfDay].
    func dailyTotals(for activity: ActivityCategory, in range: DateInterval) -> [DailyActivityTotal] {
        let startDay = range.start.startOfDay
        let endDay = range.end.startOfDay
        let entries = fetchEntries(from: startDay, to: endDay)

        // Initialize all days in the range to 0
        var totals: [Date: Int] = [:]
        var currentDay = startDay
        while currentDay <= endDay {
            totals[currentDay] = 0
            currentDay = currentDay.addingDays(1)
        }
        
        // Now populate with actual hours from entries
        for entry in entries where entry.category == activity {
            let day = entry.date.startOfDay
            totals[day, default: 0] += 1
        }

        return totals
            .map { DailyActivityTotal(date: $0.key, hours: $0.value) }
            .sorted { $0.date < $1.date }
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

    // MARK: - All-time detail stats

    private func allEntries() -> [TimeEntry] {
        if let cached = cachedAllEntries { return cached }
        let descriptor = FetchDescriptor<TimeEntry>()
        let entries = (try? context.fetch(descriptor)) ?? []
        cachedAllEntries = entries
        return entries
    }

    func detailStats(for activity: ActivityCategory) -> ActivityDetailStats {
        let all = allEntries()
        let activityEntries = all.filter { $0.category == activity }

        let totalHours = activityEntries.count

        let allDays = Set(all.map { $0.date.startOfDay })
        let totalDays = allDays.count

        let activeDaySet = Set(activityEntries.map { $0.date.startOfDay })
        let activeDays = activeDaySet.count

        let avgHoursPerDay = totalDays > 0 ? Double(totalHours) / Double(totalDays) : 0
        let frequencyPercent = totalDays > 0 ? Double(activeDays) / Double(totalDays) * 100 : 0

        // Peak hour of day
        var hourCounts: [Int: Int] = [:]
        for entry in activityEntries { hourCounts[entry.hour, default: 0] += 1 }
        let peakHour = hourCounts.max(by: { $0.value < $1.value })?.key

        // Peak day of week
        let cal = Calendar.current
        var dowCounts: [Int: Int] = [:]
        for entry in activityEntries {
            let dow = cal.component(.weekday, from: entry.date)
            dowCounts[dow, default: 0] += 1
        }
        let peakDOW = dowCounts.max(by: { $0.value < $1.value })?.key
        let peakDayName = peakDOW.map { weekdayName(for: $0) }

        // Longest streak
        let longestStreak = Self.longestStreak(in: activeDaySet)

        return ActivityDetailStats(
            totalHours: totalHours,
            avgHoursPerDay: avgHoursPerDay,
            activeDays: activeDays,
            frequencyPercent: frequencyPercent,
            peakHourOfDay: peakHour,
            peakDayOfWeek: peakDayName,
            longestStreak: longestStreak
        )
    }

    func sleepDetailStats() -> SleepStats {
        let sleepEntries = allEntries().filter { $0.category == .sleep }

        // Group by day
        var byDay: [Date: [Int]] = [:]
        for entry in sleepEntries {
            let day = entry.date.startOfDay
            byDay[day, default: []].append(entry.hour)
        }

        var durations: [Double] = []
        var bedtimes: [Double] = []
        var waketimes: [Double] = []
        var lateNightCount = 0

        for (_, hours) in byDay {
            let sorted = hours.sorted()
            guard !sorted.isEmpty else { continue }

            // Find largest contiguous block
            var blocks: [[Int]] = []
            var current: [Int] = [sorted[0]]
            for h in sorted.dropFirst() {
                if h == current.last! + 1 {
                    current.append(h)
                } else {
                    blocks.append(current)
                    current = [h]
                }
            }
            blocks.append(current)
            let main = blocks.max(by: { $0.count < $1.count })!

            durations.append(Double(main.count))
            bedtimes.append(Double(main.first!))
            waketimes.append(Double(main.last!))

            // Late night: bedtime at hour 0, 1, 2, or 3
            if main.first! <= 3 { lateNightCount += 1 }
        }

        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        let avgBedtime = bedtimes.isEmpty ? 0 : bedtimes.reduce(0, +) / Double(bedtimes.count)
        let avgWake = waketimes.isEmpty ? 0 : waketimes.reduce(0, +) / Double(waketimes.count)
        let latePercent = byDay.isEmpty ? 0 : Double(lateNightCount) / Double(byDay.count) * 100

        return SleepStats(
            avgHoursPerNight: avgDuration,
            avgBedtimeHour: avgBedtime,
            avgWakeHour: avgWake,
            lateNightPercent: latePercent
        )
    }

    func workDetailStats() -> WorkStats {
        let all = allEntries()
        let workEntries = all.filter { $0.category == .work }
        let cal = Calendar.current

        // Group work hours by day
        var workByDay: [Date: Int] = [:]
        for entry in workEntries {
            let day = entry.date.startOfDay
            workByDay[day, default: 0] += 1
        }

        // Collect all tracked days
        let allDays = Set(all.map { $0.date.startOfDay })

        var weekdayTotals: [Int] = []
        var weekendTotals: [Int] = []
        var dowHours: [Int: Int] = [:]

        for day in allDays {
            let weekday = cal.component(.weekday, from: day)
            let hours = workByDay[day] ?? 0
            // weekday: 1=Sun, 2=Mon, ..., 7=Sat
            if weekday == 1 || weekday == 7 {
                weekendTotals.append(hours)
            } else {
                weekdayTotals.append(hours)
            }
            dowHours[weekday, default: 0] += hours
        }

        let weekdayAvg = weekdayTotals.isEmpty ? 0 : Double(weekdayTotals.reduce(0, +)) / Double(weekdayTotals.count)
        let weekendAvg = weekendTotals.isEmpty ? 0 : Double(weekendTotals.reduce(0, +)) / Double(weekendTotals.count)

        // Most productive day: highest total work hours per weekday divided by days-count of that weekday
        var dowDayCounts: [Int: Int] = [:]
        for day in allDays {
            let dow = cal.component(.weekday, from: day)
            dowDayCounts[dow, default: 0] += 1
        }
        let mostProductiveDOW = dowHours
            .filter { $0.key != 1 && $0.key != 7 }
            .max(by: {
                let a = Double($0.value) / Double(dowDayCounts[$0.key] ?? 1)
                let b = Double($1.value) / Double(dowDayCounts[$1.key] ?? 1)
                return a < b
            })?.key
        let mostProductiveDay = mostProductiveDOW.map { weekdayName(for: $0) }

        return WorkStats(
            weekdayAvgHours: weekdayAvg,
            weekendAvgHours: weekendAvg,
            mostProductiveDayOfWeek: mostProductiveDay
        )
    }

    func exerciseDetailStats() -> ExerciseStats {
        let exerciseEntries = allEntries().filter { $0.category == .exercise }

        let activeDays = Set(exerciseEntries.map { $0.date.startOfDay }).count
        let total = exerciseEntries.count
        let avgOnActiveDays = activeDays > 0 ? Double(total) / Double(activeDays) : 0

        let lateCount = exerciseEntries.filter { $0.hour > 19 }.count
        let latePercent = total > 0 ? Double(lateCount) / Double(total) * 100 : 0

        return ExerciseStats(avgHoursOnActiveDays: avgOnActiveDays, lateExercisePercent: latePercent)
    }

    // MARK: - Private helpers

    private func weekdayName(for weekday: Int) -> String {
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat (Calendar.current)
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let index = (weekday - 1) % 7
        return names[index]
    }

    private static func longestStreak(in days: Set<Date>) -> Int {
        let sorted = days.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            if Calendar.current.dateComponents([.day], from: prev, to: curr).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
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
