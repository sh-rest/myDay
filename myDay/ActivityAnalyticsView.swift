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
