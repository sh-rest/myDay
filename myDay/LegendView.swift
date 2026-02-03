import SwiftUI

struct LegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legend")
                .font(.headline)

            ForEach(ActivityCategory.allCases, id: \.self) { category in
                HStack(spacing: 12) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 16, height: 16)

                    Text(category.displayName)

                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    LegendView()
}
