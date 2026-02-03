import SwiftUI

struct ActivityPickerSheet: View {
    let date: Date
    let hour: Int
    let onSelect: (ActivityCategory) -> Void

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }

    private var hourLabel: String {
        let start = hour
        let end = min(23, hour + 1)
        let startDate = Calendar.current.date(bySettingHour: start, minute: 0, second: 0, of: date) ?? date
        let endDate = Calendar.current.date(bySettingHour: end, minute: 0, second: 0, of: date) ?? date
        let tf = DateFormatter()
        tf.dateFormat = "h a"
        let startStr = tf.string(from: startDate)
        let endStr = tf.string(from: endDate)
        return "\(startStr) – \(endStr)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Selected")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: date)).font(.headline)
                        Text(hourLabel).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Activities")) {
                    ForEach(ActivityCategory.allCases, id: \.self) { cat in
                        Button(action: { onSelect(cat) }) {
                            HStack(spacing: 12) {
                                Circle().foregroundStyle(cat.color).frame(width: 16, height: 16)
                                Text(cat.displayName)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ActivityPickerSheet(date: Date(), hour: 15) { _ in }
}
