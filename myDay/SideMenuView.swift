import SwiftUI

struct SideMenuView: View {
    let onSelectAnalytics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: {
                onSelectAnalytics()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                    Text("View Analytics")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    SideMenuView(onSelectAnalytics: {})
}
