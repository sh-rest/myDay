import SwiftUI

struct LegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Legend", systemImage: "circle.grid.2x2")
                .font(.subheadline)


            VStack(alignment: .leading, spacing: 8) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 10, height: 10)

                        Text(category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    LegendView()
}


//HStack(spacing: 10) {
//Circle()
//    .fill(category.color)
//    .frame(width: 10, height: 10)
//
//Text(category.displayName)
//    .font(.subheadline)
//    .foregroundStyle(.primary)
//
//Spacer(minLength: 0)
//}
//.padding(.vertical, 6)
//.padding(.horizontal, 12)
//.background(
//RoundedRectangle(cornerRadius: 12, style: .continuous)
//    .fill(Color(.secondarySystemBackground))
//)
