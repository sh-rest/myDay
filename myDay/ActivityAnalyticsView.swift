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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(activity.color)
                    .frame(width: 12, height: 12)
                Text(activity.displayName)
                    .font(.headline)
            }
            .padding(.top, 8)

            Text("Last 30 days")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                .foregroundStyle(activity.color.opacity(0.8))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: 0...24)
            .frame(minHeight: 240)

            Spacer()
        }
        .padding()
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
