import SwiftUI
import Charts
import SwiftData

struct ActivityAnalyticsView: View {
    let activity: ActivityCategory
    @ObservedObject var viewModel: AnalyticsViewModel

    // Last 30 days, inclusive of today
    private var dateRange: DateInterval {
        let end = Date().startOfDay
        let start = end.addingDays(-29)
        return DateInterval(start: start, end: end)
    }

    private var dailyData: [AnalyticsViewModel.DailyActivityTotal] {
        viewModel.dailyTotals(for: activity, in: dateRange)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 10) {
                    Circle()
                        .fill(activity.color)
                        .frame(width: 12, height: 12)
                    Text(activity.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 4)

                Text("Last 30 Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Chart card
                Chart(dailyData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Hours", item.hours)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(activity.color)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(activity.color.opacity(0.9))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color(.quaternaryLabel))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color(.quaternaryLabel))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: 0...24)
                .frame(height: 260)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                // Past-year heatmap
                HeatmapSectionView(activity: activity, data: viewModel.yearlyTotals(for: activity))

                // All-time statistics
                let stats = viewModel.detailStats(for: activity)
                StatsSectionView(activity: activity, stats: stats)

                // Activity-specific extras
                if activity == .sleep {
                    let sleepStats = viewModel.sleepDetailStats()
                    SleepTimingSection(stats: sleepStats, color: activity.color)
                } else if activity == .work {
                    let workStats = viewModel.workDetailStats()
                    WorkBreakdownSection(stats: workStats, color: activity.color)
                } else if activity == .exercise {
                    let exStats = viewModel.exerciseDetailStats()
                    ExerciseBreakdownSection(stats: exStats, color: activity.color)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(activity.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Universal stats grid

private struct StatsSectionView: View {
    let activity: ActivityCategory
    let stats: AnalyticsViewModel.ActivityDetailStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Time")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Total Hours", value: "\(stats.totalHours) h")
                StatCard(label: "Avg / Day", value: formatDecimal(stats.avgHoursPerDay) + " h")
                StatCard(label: "Active Days", value: "\(stats.activeDays)")
                StatCard(label: "Frequency", value: formatDecimal(stats.frequencyPercent) + "%")
                if let peak = stats.peakHourOfDay {
                    StatCard(label: "Peak Hour", value: formatHour(peak))
                }
                if let day = stats.peakDayOfWeek {
                    StatCard(label: "Best Day", value: day)
                }
                StatCard(label: "Longest Streak", value: "\(stats.longestStreak) days")
            }
        }
    }
}

// MARK: - Sleep timing section

private struct SleepTimingSection: View {
    let stats: AnalyticsViewModel.SleepStats
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Timing")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Avg Sleep", value: formatDecimal(stats.avgHoursPerNight) + " h")
                StatCard(label: "Late Nights", value: formatDecimal(stats.lateNightPercent) + "%")
                StatCard(label: "Avg Bedtime", value: formatHour(Int(stats.avgBedtimeHour.rounded())))
                StatCard(label: "Avg Wake", value: formatHour(Int(stats.avgWakeHour.rounded())))
            }
        }
    }
}

// MARK: - Work breakdown section

private struct WorkBreakdownSection: View {
    let stats: AnalyticsViewModel.WorkStats
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekday vs Weekend")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Weekday Avg", value: formatDecimal(stats.weekdayAvgHours) + " h/day")
                StatCard(label: "Weekend Avg", value: formatDecimal(stats.weekendAvgHours) + " h/day")
                if let best = stats.mostProductiveDayOfWeek {
                    StatCard(label: "Best Weekday", value: best)
                }
            }
        }
    }
}

// MARK: - Exercise breakdown section

private struct ExerciseBreakdownSection: View {
    let stats: AnalyticsViewModel.ExerciseStats
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Habits")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "Avg on Active Days", value: formatDecimal(stats.avgHoursOnActiveDays) + " h")
                StatCard(label: "After 7 PM", value: formatDecimal(stats.lateExercisePercent) + "%")
            }
        }
    }
}

// MARK: - Reusable stat card

private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Heatmap

private struct HeatmapSectionView: View {
    let activity: ActivityCategory
    let data: [AnalyticsViewModel.DailyActivityTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Year")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HeatmapGridView(data: data, color: activity.color)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

private struct HeatmapGridView: View {
    let data: [AnalyticsViewModel.DailyActivityTotal]
    let color: Color

    // Group flat day list into week columns (Mon=0 … Sun=6).
    // Pad the first partial week with nils so Mon always sits at row 0.
    private var weeks: [[AnalyticsViewModel.DailyActivityTotal?]] {
        guard let first = data.first else { return [] }
        let cal = Calendar.current
        // weekday: 1=Sun…7=Sat → convert to 0=Mon…6=Sun
        let rawWD = cal.component(.weekday, from: first.date)
        let offset = (rawWD + 5) % 7   // Mon=0, Tue=1, … Sun=6
        var padded: [AnalyticsViewModel.DailyActivityTotal?] = Array(repeating: nil, count: offset)
        padded.append(contentsOf: data.map { Optional($0) })
        // chunk into groups of 7
        var result: [[AnalyticsViewModel.DailyActivityTotal?]] = []
        var i = 0
        while i < padded.count {
            let end = min(i + 7, padded.count)
            var week = Array(padded[i..<end])
            while week.count < 7 { week.append(nil) }
            result.append(week)
            i += 7
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 2) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                        WeekColumnView(week: week, color: color,
                                       monthLabel: monthLabel(for: idx, week: week))
                        .id(idx)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(weeks.count - 1, anchor: .trailing)
            }
        }
    }

    private func monthLabel(for idx: Int, week: [AnalyticsViewModel.DailyActivityTotal?]) -> String? {
        guard let entry = week.compactMap({ $0 }).first else { return nil }
        let cal = Calendar.current
        let month = cal.component(.month, from: entry.date)
        // Show label only on the first week of each new month
        if idx == 0 { return monthAbbrev(month) }
        let prevWeek = weeks[idx - 1]
        if let prevEntry = prevWeek.compactMap({ $0 }).first {
            let prevMonth = cal.component(.month, from: prevEntry.date)
            if prevMonth != month { return monthAbbrev(month) }
        }
        return nil
    }

    private func monthAbbrev(_ month: Int) -> String {
        let abbrevs = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return abbrevs[(month - 1) % 12]
    }
}

private struct WeekColumnView: View {
    let week: [AnalyticsViewModel.DailyActivityTotal?]
    let color: Color
    let monthLabel: String?

    var body: some View {
        VStack(spacing: 2) {
            // Month label header — fixed height so all columns align
            Text(monthLabel ?? "")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .frame(height: 10)

            ForEach(0..<7, id: \.self) { row in
                if let entry = week[row] {
                    HeatmapCell(hours: entry.hours, color: color)
                } else {
                    Color.clear.frame(width: 12, height: 12)
                }
            }
        }
    }
}

private struct HeatmapCell: View {
    let hours: Int
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(cellColor)
            .frame(width: 12, height: 12)
    }

    private var cellColor: Color {
        switch hours {
        case 0:    return Color(.systemFill)
        case 1...2: return color.opacity(0.3)
        case 3...5: return color.opacity(0.55)
        case 6...8: return color.opacity(0.8)
        default:   return color
        }
    }
}

// MARK: - Formatting helpers (file-private)

private func formatDecimal(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 1
    f.minimumFractionDigits = 0
    return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
}

private func formatHour(_ hour: Int) -> String {
    let h = hour % 24
    let suffix = h < 12 ? "AM" : "PM"
    let display = h % 12 == 0 ? 12 : h % 12
    return "\(display) \(suffix)"
}

#Preview {
    NavigationStack {
        // Preview with an empty view model container; data is not critical here.
        let schema = Schema([TimeEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let viewModel = AnalyticsViewModel(context: context)
        ActivityAnalyticsView(activity: .work, viewModel: viewModel)
    }
}
