import SwiftUI

struct SuggestionManagerView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var vm: SuggestionManagerViewModel
  @State private var showsUndoToast = false

  init(repository: SuggestionRepository, fieldType: String) {
    _vm = StateObject(
      wrappedValue: SuggestionManagerViewModel(repository: repository, fieldType: fieldType))
  }

  var body: some View {
    ZStack {
      SuggestionManagerStyle.background.ignoresSafeArea()

      VStack(spacing: SuggestionManagerStyle.sectionSpacing) {
        header
        controlsCard

        List {
          ForEach(vm.suggestions) { suggestion in
            SuggestionRow(suggestion: suggestion)
              .listRowSeparator(.hidden)
              .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
              .listRowBackground(Color.clear)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if suggestion.isDeleted {
                  Button {
                    vm.restore(suggestion.id)
                  } label: {
                    swipeActionLabel(
                      title: "復元",
                      fill: SuggestionManagerStyle.restoreFill,
                      text: SuggestionManagerStyle.restoreText
                    )
                  }
                  .tint(SuggestionManagerStyle.restoreFill)
                } else {
                  Button {
                    vm.softDelete(suggestion.id)
                    showsUndoToast = true
                    Task {
                      try? await Task.sleep(nanoseconds: 3_000_000_000)
                      showsUndoToast = false
                    }
                  } label: {
                    swipeActionLabel(
                      title: "削除",
                      fill: SuggestionManagerStyle.destructiveFill,
                      text: SuggestionManagerStyle.destructiveText
                    )
                  }
                  .tint(SuggestionManagerStyle.destructiveFill)
                }
              }
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .modifier(SuggestionManagerRowSpacing())
      }
      .padding(.horizontal, SuggestionManagerStyle.horizontalPadding)
      .padding(.top, 20)
    }
    .overlay(alignment: .bottom) {
      if showsUndoToast {
        HStack(spacing: 12) {
          Text("削除しました")
            .font(SuggestionManagerStyle.toastFont)
            .foregroundColor(SuggestionManagerStyle.toastText)
          Spacer()
          Button("元に戻す") {
            vm.undoDelete()
            showsUndoToast = false
          }
          .font(SuggestionManagerStyle.toastButtonFont)
          .foregroundColor(SuggestionManagerStyle.toastButtonText)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(SuggestionManagerStyle.toastFill)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(SuggestionManagerStyle.toastBorder, lineWidth: 1)
            )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.bottom, 18)
        .animation(.easeInOut, value: showsUndoToast)
      }
    }
    .onAppear { vm.fetch() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("候補を管理")
          .font(SuggestionManagerStyle.headerFont)
          .foregroundColor(SuggestionManagerStyle.headerText)
        Text(vm.title)
          .font(SuggestionManagerStyle.subheaderFont)
          .foregroundColor(SuggestionManagerStyle.subheaderText)
      }
      Spacer()
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(SuggestionManagerStyle.closeIcon)
          .frame(width: 28, height: 28)
          .background(
            Circle()
              .stroke(SuggestionManagerStyle.closeBorder, lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
    }
  }

  private var controlsCard: some View {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(SuggestionManagerStyle.inputIcon)
        TextField("検索", text: $vm.query)
          .font(SuggestionManagerStyle.inputFont)
          .foregroundColor(SuggestionManagerStyle.inputText)
      }
      .padding(.horizontal, 12)
      .frame(height: SuggestionManagerStyle.inputHeight)
      .background(
        RoundedRectangle(cornerRadius: SuggestionManagerStyle.inputCornerRadius)
          .fill(SuggestionManagerStyle.inputFill)
          .overlay(
            RoundedRectangle(cornerRadius: SuggestionManagerStyle.inputCornerRadius)
              .stroke(
                SuggestionManagerStyle.inputBorder,
                lineWidth: SuggestionManagerStyle.inputBorderWidth)
          )
      )

      Toggle(isOn: $vm.includeDeleted) {
        VStack(alignment: .leading, spacing: 4) {
          Text("削除済みを表示")
            .font(SuggestionManagerStyle.toggleTitleFont)
            .foregroundColor(SuggestionManagerStyle.toggleTitleText)
          Text("ONにすると削除済み候補を表示し、復元できます")
            .font(SuggestionManagerStyle.toggleBodyFont)
            .foregroundColor(SuggestionManagerStyle.toggleBodyText)
        }
      }
      .toggleStyle(SwitchToggleStyle(tint: SuggestionManagerStyle.toggleTint))
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.cardCornerRadius)
        .fill(SuggestionManagerStyle.cardFill)
        .overlay(
          RoundedRectangle(cornerRadius: SuggestionManagerStyle.cardCornerRadius)
            .stroke(SuggestionManagerStyle.cardBorder, lineWidth: 1)
        )
    )
  }

  private func swipeActionLabel(title: String, fill: Color, text: Color) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
        .fill(fill)
      Text(title)
        .font(SuggestionManagerStyle.swipeActionFont)
        .foregroundColor(text)
    }
    .frame(width: 72, height: SuggestionManagerStyle.rowHeight)
  }
}

private struct SuggestionManagerRowSpacing: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.0, *) {
      content.listRowSpacing(SuggestionManagerStyle.rowSpacing)
    } else {
      content
    }
  }
}

private struct SuggestionRow: View {
  let suggestion: Suggestion

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(suggestion.value)
          .font(SuggestionManagerStyle.rowTitleFont)
          .foregroundColor(
            suggestion.isDeleted
              ? SuggestionManagerStyle.deletedText : SuggestionManagerStyle.rowTitleText)
        Text("使用: \(suggestion.usageCount)")
          .font(SuggestionManagerStyle.rowMetaFont)
          .foregroundColor(SuggestionManagerStyle.rowMetaText)
      }
      Spacer(minLength: 0)
      if suggestion.isDeleted {
        Text("削除済み")
          .font(SuggestionManagerStyle.deletedBadgeFont)
          .foregroundColor(SuggestionManagerStyle.deletedBadgeText)
          .padding(.horizontal, 8)
          .frame(height: 20)
          .background(
            Capsule()
              .fill(SuggestionManagerStyle.deletedBadgeFill)
              .overlay(
                Capsule()
                  .stroke(SuggestionManagerStyle.deletedBadgeBorder, lineWidth: 1)
              )
          )
      }
    }
    .padding(.horizontal, SuggestionManagerStyle.rowHorizontalPadding)
    .padding(.vertical, SuggestionManagerStyle.rowVerticalPadding)
    .frame(height: SuggestionManagerStyle.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
        .fill(SuggestionManagerStyle.rowFill)
        .overlay(
          RoundedRectangle(cornerRadius: SuggestionManagerStyle.rowCornerRadius, style: .continuous)
            .stroke(SuggestionManagerStyle.rowBorder, lineWidth: 1)
        )
    )
  }
}

private enum SuggestionManagerStyle {
  static let horizontalPadding: CGFloat = 16
  static let sectionSpacing: CGFloat = 16
  static let inputHeight: CGFloat = 40
  static let inputCornerRadius: CGFloat = 10
  static let inputBorderWidth: CGFloat = 0.66
  static let cardCornerRadius: CGFloat = 12
  static let rowCornerRadius: CGFloat = 12
  static let rowHeight: CGFloat = 56
  static let rowVerticalPadding: CGFloat = 8
  static let rowHorizontalPadding: CGFloat = 12
  static let rowSpacing: CGFloat = 10

  static let background = Color(hex: "FFFFFF")
  static let cardFill = Color(hex: "F9FAFB")
  static let cardBorder = Color(hex: "E5E7EB")
  static let inputFill = Color(hex: "FFFFFF")
  static let inputBorder = Color(hex: "D1D5DC")
  static let inputText = Color(hex: "0A0A0A")
  static let inputIcon = Color(hex: "6B7280")
  static let headerText = Color(hex: "2A2525")
  static let subheaderText = Color(hex: "6B7280")
  static let closeIcon = Color(hex: "364153")
  static let closeBorder = Color(hex: "D1D5DC")
  static let toggleTitleText = Color(hex: "2A2525")
  static let toggleBodyText = Color(hex: "6B7280")
  static let toggleTint = HomeStyle.fabRed

  static let rowFill = Color(hex: "FFFFFF")
  static let rowBorder = Color(hex: "E5E7EB")
  static let rowTitleText = Color(hex: "2A2525")
  static let rowMetaText = Color(hex: "6B7280")
  static let deletedText = Color(hex: "9CA3AF")
  static let deletedBadgeFill = Color(hex: "F3F4F6")
  static let deletedBadgeBorder = Color(hex: "D1D5DC")
  static let deletedBadgeText = Color(hex: "6B7280")
  static let destructiveFill = HomeStyle.destructiveRed
  static let destructiveText = Color.white
  static let restoreFill = Color(hex: "16A34A")
  static let restoreText = Color.white

  static let toastFill = Color(hex: "FFFFFF")
  static let toastBorder = Color(hex: "E5E7EB")
  static let toastText = Color(hex: "2A2525")
  static let toastButtonText = HomeStyle.fabRed

  static let headerFont = Font.custom("Roboto-Medium", size: 20)
  static let subheaderFont = Font.custom("Roboto", size: 13)
  static let inputFont = Font.custom("Roboto", size: 16)
  static let toggleTitleFont = Font.custom("Roboto-Medium", size: 14)
  static let toggleBodyFont = Font.custom("Roboto", size: 12)
  static let rowTitleFont = Font.custom("Roboto-Medium", size: 15)
  static let rowMetaFont = Font.custom("Roboto", size: 12)
  static let deletedBadgeFont = Font.custom("Roboto-Medium", size: 11)
  static let swipeActionFont = Font.custom("Roboto-Medium", size: 14)
  static let toastFont = Font.custom("Roboto-Medium", size: 13)
  static let toastButtonFont = Font.custom("Roboto-Medium", size: 13)
}
