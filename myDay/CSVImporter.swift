import Foundation
import SwiftData

struct CSVImporter {

    struct Result {
        let inserted: Int
        let updated: Int
        let skipped: Int
    }

    // MARK: - Public entry point

    static func importTimeEntries(from url: URL, context: ModelContext) throws -> Result {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let raw = try String(contentsOf: url, encoding: .utf8)
        let lines = raw.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return Result(inserted: 0, updated: 0, skipped: 0) }

        let header = lines[0].lowercased()
        if header.hasPrefix("date,day") || header.hasPrefix("date, day") {
            return try importSheetFormat(lines: lines, context: context)
        } else {
            return try importAppFormat(lines: lines, context: context)
        }
    }

    // MARK: - App export format  (date,hour,activity)

    private static func importAppFormat(lines: [String], context: ModelContext) throws -> Result {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var inserted = 0, updated = 0, skipped = 0

        for (idx, line) in lines.enumerated() {
            if idx == 0 { continue }
            let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: ",")
            guard parts.count >= 3,
                  let date = dateFormatter.date(from: parts[0].trimmingCharacters(in: .whitespaces)),
                  let hour = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                  hour >= 0, hour <= 23,
                  let category = ActivityCategory(rawValue: parts[2].trimmingCharacters(in: .whitespaces))
            else { skipped += 1; continue }

            try upsert(date: date.startOfDay, hour: hour, category: category, context: context,
                       inserted: &inserted, updated: &updated)
        }

        try context.save()
        return Result(inserted: inserted, updated: updated, skipped: skipped)
    }

    // MARK: - Google Sheet format  (DATE DD/MM, DAY, 12am … 11pm)

    /// Number → ActivityCategory mapping from the sheet legend.
    private static let sheetMapping: [Int: ActivityCategory] = [
        0: .sleep, 1: .work, 2: .food, 3: .productive, 4: .exercise,
        5: .friends, 6: .leisure, 7: .family, 8: .misc, 9: .travel, 10: .misc
    ]

    private static func importSheetFormat(lines: [String], context: ModelContext) throws -> Result {
        let cal = Calendar.current
        let today = Date().startOfDay
        let currentYear = cal.component(.year, from: today)

        var inserted = 0, updated = 0, skipped = 0

        for (idx, line) in lines.enumerated() {
            if idx == 0 { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let cols = trimmed.components(separatedBy: ",")
            guard cols.count >= 3 else { continue }

            // Parse DD/MM date, infer year
            guard let date = parseSheetDate(cols[0], currentYear: currentYear, today: today) else { continue }

            // Columns 2–25 are hours 0–23
            for hour in 0..<24 {
                let colIdx = hour + 2
                guard colIdx < cols.count else { break }
                let cell = cols[colIdx].trimmingCharacters(in: .whitespaces)
                guard !cell.isEmpty, let code = Int(cell), let category = sheetMapping[code] else {
                    skipped += 1; continue
                }
                try upsert(date: date, hour: hour, category: category, context: context,
                           inserted: &inserted, updated: &updated)
            }
        }

        try context.save()
        return Result(inserted: inserted, updated: updated, skipped: skipped)
    }

    /// Parses "DD/M" or "D/MM" etc. Picks current year; if that date is in the future, uses previous year.
    private static func parseSheetDate(_ raw: String, currentYear: Int, today: Date) -> Date? {
        let parts = raw.trimmingCharacters(in: .whitespaces).components(separatedBy: "/")
        guard parts.count == 2,
              let day = Int(parts[0]), let month = Int(parts[1]) else { return nil }

        let cal = Calendar.current
        func makeDate(year: Int) -> Date? {
            cal.date(from: DateComponents(year: year, month: month, day: day))?.startOfDay
        }

        if let d = makeDate(year: currentYear) {
            return d > today ? makeDate(year: currentYear - 1) : d
        }
        return nil
    }

    // MARK: - Shared upsert

    private static func upsert(date: Date, hour: Int, category: ActivityCategory,
                                context: ModelContext, inserted: inout Int, updated: inout Int) throws {
        let key = TimeEntry.makeDayHourKey(for: date, hour: hour)
        var descriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.dayHourKey == key })
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.category = category
            updated += 1
        } else {
            context.insert(TimeEntry(date: date, hour: hour, category: category))
            inserted += 1
        }
    }
}
