import SwiftUI

struct BackupPassphraseSheet: View {
    let title: String
    let subtitle: String
    let confirmButtonTitle: String
    let requiresConfirmation: Bool
    let isProcessing: Bool
    let minimumLength: Int
    let onSubmit: (_ passphrase: String, _ confirmation: String) -> Void
    let onCancel: () -> Void

    @State private var passphrase = ""
    @State private var confirmation = ""

    private var validationMessage: String? {
        if passphrase.count < minimumLength {
            return "パスフレーズは\(minimumLength)文字以上で入力してください。"
        }
        if requiresConfirmation && passphrase != confirmation {
            return "確認用パスフレーズが一致しません。"
        }
        return nil
    }

    private var canSubmit: Bool {
        validationMessage == nil && !passphrase.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(subtitle)
                    .font(AppTypography.subtext)
                    .foregroundColor(HomeStyle.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("パスフレーズ")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(HomeStyle.textPrimary)
                    SecureField("8文字以上", text: $passphrase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                        )
                }

                if requiresConfirmation {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("パスフレーズ（確認）")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(HomeStyle.textPrimary)
                        SecureField("再入力", text: $confirmation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                            )
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(AppTypography.meta)
                        .foregroundColor(.red)
                }

                Spacer(minLength: 0)

                Button {
                    onSubmit(passphrase, confirmation)
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(confirmButtonTitle)
                    }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(HomeStyle.fabRed)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!canSubmit || isProcessing)

                Button("キャンセル", role: .cancel, action: onCancel)
                    .font(AppTypography.body)
                    .foregroundColor(HomeStyle.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .disabled(isProcessing)
            }
            .padding(20)
            .background(HomeStyle.screenBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
