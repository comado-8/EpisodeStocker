import SwiftUI

struct StatusBadge: View {
    let isUnlocked: Bool

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
        isUnlocked ? "解禁OK" : "解禁前"
    }

    private var background: Color {
        isUnlocked ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
    }
}

struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            StatusBadge(isUnlocked: false)
            StatusBadge(isUnlocked: true)
        }
        .padding()
    }
}
