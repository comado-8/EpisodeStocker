import SwiftUI

struct StatusBadge: View {
    let status: EpisodeStatus

    var body: some View {
        Text(label)
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var label: String {
        switch status {
        case .unpublished: return "未公開"
        case .published: return "公開済み"
        }
    }

    private var background: Color {
        switch status {
        case .unpublished: return Color.orange.opacity(0.2)
        case .published: return Color.green.opacity(0.2)
        }
    }
}

struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            StatusBadge(status: .unpublished)
            StatusBadge(status: .published)
        }
        .padding()
    }
}
