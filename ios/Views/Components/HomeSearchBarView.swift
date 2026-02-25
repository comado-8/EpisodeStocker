import SwiftUI

struct HomeSearchBarView: View {
    @Binding var text: String
    let width: CGFloat
    let isFocused: FocusState<Bool>.Binding
    var placeholder: String = "エピソードを検索"
    var showsBack: Bool = false
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var onClearText: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button {
                    onCancel?()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(HomeStyle.segmentText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索を閉じる")
            }
            ZStack(alignment: .leading) {
                if text.isEmpty && !isFocused.wrappedValue {
                    Text(placeholder)
                        .font(HomeFont.bodyLarge())
                        .tracking(0.5)
                        .foregroundColor(HomeStyle.segmentText)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(HomeFont.bodyLarge())
                    .tracking(0.5)
                    .foregroundColor(HomeStyle.segmentText)
                    .submitLabel(.search)
                    .onSubmit {
                        onSubmit?()
                    }
                    .focused(isFocused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isFocused.wrappedValue {
                Button {
                    isFocused.wrappedValue = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(HomeStyle.segmentText.opacity(0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索入力を閉じる")
            } else if !text.isEmpty {
                Button {
                    if let onClearText {
                        onClearText()
                    } else {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(HomeStyle.segmentText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("入力をクリア")
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(HomeStyle.segmentText)
            }
        }
        .padding(.horizontal, 16)
        .frame(width: width, height: HomeStyle.searchHeight)
        .background(isFocused.wrappedValue ? HomeStyle.searchActiveFill : HomeStyle.searchFill)
        .overlay(
            Capsule()
                .stroke(
                    isFocused.wrappedValue ? HomeStyle.searchActiveBorder : HomeStyle.searchBorder,
                    lineWidth: 0.9
                )
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            isFocused.wrappedValue = true
        }
    }
}

struct HomeSearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        HomeSearchBarViewPreviewWrapper()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

private struct HomeSearchBarViewPreviewWrapper: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HomeSearchBarView(text: $text, width: 360, isFocused: $isFocused)
    }
}
