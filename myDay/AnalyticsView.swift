import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak")
                        .font(.headline)
                    Text("\(viewModel.streakCount) day\(viewModel.streakCount == 1 ? "" : "s") in a row")
                        .font(.title3)
                        .bold()
                }
                .padding(.vertical, 4)
            }

            Section("Activity Averages") {
                ForEach(ActivityCategory.allCases, id: \.self) { activity in
                    if let stats = viewModel.activityStats[activity] {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.displayName)
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Text("This week: \(formatHours(stats.currentWeekAverageHoursPerDay)) h/day")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("Last week: \(formatHours(stats.previousWeekAverageHoursPerDay)) h/day")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            changeIcon(for: stats.change)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func formatHours(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    @ViewBuilder
    private func changeIcon(for change: AnalyticsViewModel.WeekOverWeekChange) -> some View {
        switch change {
        case .increase:
            Image(systemName: "arrow.up")
                .foregroundStyle(.green)
        case .decrease:
            Image(systemName: "arrow.down")
                .foregroundStyle(.red)
        case .noChange:
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    do {
        let schema = Schema([TimeEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        return NavigationStack {
            AnalyticsView(context: context)
        }
    } catch {
        return NavigationStack {
            Text("Preview error: \\(error.localizedDescription)")
        }
    }
}
