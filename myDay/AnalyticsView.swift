import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel

    // Currently selected activity for the detail sheet
    @State private var selectedActivity: ActivityCategory? = nil

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(context: context))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Streak card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Streak")
                        .font(.headline)
                    Text("\(viewModel.streakCount) day\(viewModel.streakCount == 1 ? "" : "s") in a row")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                // Activity averages header
                Text("Activity Averages")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                // Activity cards
                VStack(spacing: 12) {
                    ForEach(ActivityCategory.allCases, id: \.self) { activity in
                        if let stats = viewModel.activityStats[activity] {
                            Button {
                                selectedActivity = activity
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(activity.color)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(activity.displayName)
                                            .font(.headline)

                                        HStack(alignment: .top, spacing: 16) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("This week")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("\(formatHours(stats.currentWeekAverageHoursPerDay)) h/day")
                                                    .font(.subheadline)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Last week")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("\(formatHours(stats.previousWeekAverageHoursPerDay)) h/day")
                                                    .font(.subheadline)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedActivity) { activity in
            NavigationStack {
                ActivityAnalyticsView(activity: activity, viewModel: viewModel)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Helpers

    private func formatHours(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
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
