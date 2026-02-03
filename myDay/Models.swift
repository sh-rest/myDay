import SwiftUI
import Foundation
import SwiftData

// MARK: - ActivityCategory
public enum ActivityCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case sleep
    case work
    case food
    case productive
    case exercise
    case friends
    case leisure
    case family
    case chores
    case travel
    case misc

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sleep: return "Sleep"
        case .work: return "Work"
        case .food: return "Food"
        case .productive: return "Productive"
        case .exercise: return "Exercise"
        case .friends: return "Friends"
        case .leisure: return "Leisure"
        case .family: return "Family"
        case .chores: return "Chores"
        case .travel: return "Travel"
        case .misc: return "Misc / Getting Ready"
        }
    }

    public var color: Color {
        switch self {
        case .sleep: return Color.indigo
        case .work: return Color.blue
        case .food: return Color.orange
        case .productive: return Color.teal
        case .exercise: return Color.green
        case .friends: return Color.pink
        case .leisure: return Color.purple
        case .family: return Color.cyan
        case .chores: return Color.brown
        case .travel: return Color.red
        case .misc: return Color.gray
        }
    }
}

// MARK: - TimeEntry (SwiftData Model)
/// Represents a single hour block on a given logical day.
///
/// Data integrity guarantees:
/// - Only a single `TimeEntry` should exist for a given (date, hour) pair.
/// - `date` is always normalized to the start of the logical day (local calendar).
/// - `dayHourKey` is a stable, unique key for (date, hour) and is enforced as unique by SwiftData.
@Model
public final class TimeEntry {
    /// Stable identifier for the row.
    @Attribute(.unique) public var id: UUID

    /// Unique key combining logical day + hour, used to enforce one entry per slot.
    /// Example: "2026-02-03-13" for Feb 3, 2026 at 1PM.
    @Attribute(.unique) public var dayHourKey: String

    /// Logical day, always stored as start-of-day in the current calendar.
    public var date: Date // normalized to midnight for the day

    /// Hour-of-day in 0...23 on the logical day.
    public var hour: Int // 0...23

    /// Backing storage for the category enum.
    public var categoryRaw: String

    public var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .misc }
        set { categoryRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), date: Date, hour: Int, category: ActivityCategory) {
        self.id = id

        let normalizedDay = date.startOfDay
        let clampedHour = max(0, min(23, hour))

        self.date = normalizedDay
        self.hour = clampedHour
        self.categoryRaw = category.rawValue
        self.dayHourKey = TimeEntry.makeDayHourKey(for: normalizedDay, hour: clampedHour)
    }

    /// Builds a stable unique key for a (day, hour) pair.
    /// Uses calendar components so it is resilient to daylight savings transitions
    /// and minor timezone changes after the fact.
    public static func makeDayHourKey(for day: Date, hour: Int) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: day.startOfDay)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        let clampedHour = max(0, min(23, hour))
        return String(format: "%04d-%02d-%02d-%02d", y, m, d, clampedHour)
    }
}

// MARK: - Date Helpers
public extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
