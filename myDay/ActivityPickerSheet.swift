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
        return "\(tf.string(from: startDate)) – \(tf.string(from: endDate))"
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
//        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Selected section
                Section(header: Text("Selected")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: date))
                            .font(.headline)
                        Text(hourLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Activities section
                Section(header: Text("Activities")) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ActivityCategory.allCases, id: \.self) { cat in
                            Button {
                                onSelect(cat)
                            } label: {
                                HStack(spacing: 8) {
                                    // Left color accent
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(cat.color)
                                        .frame(width: 10)

                                    Text(cat.displayName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 30)
//                                .liquidGlass(accent: Color.white)
//                                .opacity(0.5)
//                                .background(
//                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
//                                            .fill(.ultraThinMaterial)
//                                            .frame(height: 40)
//                                    )
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
//                                            .stroke(.quaternary, lineWidth: 0.5)
//                                    )
                            }
                            .buttonStyle(.glass)
//                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 14))

                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct LiquidGlassTile: ViewModifier {
    var accentColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Glass material
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle glow
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            accentColor.opacity(0.35),
                            lineWidth: 0.8
                        )
                        .blur(radius: 1.5)
                }
            )
            .overlay(
                // Crisp edge
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

extension View {
    func liquidGlass(accent: Color) -> some View {
        modifier(LiquidGlassTile(accentColor: accent))
    }
}



#Preview {
    ActivityPickerSheet(date: Date(), hour: 15) { _ in }
}
