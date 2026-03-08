import SwiftUI

struct ManualRestoreConfirmationSheet: View {
    let preview: ManualBackupPreview
    let isRestoring: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var createdAtText: String {
        Self.dateFormatter.string(from: preview.manifest.createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("現在のデータは削除され、バックアップ内容に置き換わります。")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(.red)

                Group {
                    ManualRestoreSummaryRow(title: "作成日時", value: createdAtText)
                    ManualRestoreSummaryRow(title: "形式バージョン", value: "v\(preview.manifest.schemaVersion)")
                    ManualRestoreSummaryRow(title: "エピソード", value: "\(preview.episodeCount)件")
                    ManualRestoreSummaryRow(title: "解禁ログ", value: "\(preview.unlockLogCount)件")
                    ManualRestoreSummaryRow(title: "タグ", value: "\(preview.tagCount)件")
                    ManualRestoreSummaryRow(title: "人物", value: "\(preview.personCount)件")
                    ManualRestoreSummaryRow(title: "企画", value: "\(preview.projectCount)件")
                    ManualRestoreSummaryRow(title: "感情", value: "\(preview.emotionCount)件")
                    ManualRestoreSummaryRow(title: "場所", value: "\(preview.placeCount)件")
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        if isRestoring {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("この内容で復元する")
                    }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isRestoring)

                Button("キャンセル", role: .cancel, action: onCancel)
                    .font(AppTypography.body)
                    .foregroundColor(HomeStyle.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .disabled(isRestoring)
            }
            .padding(20)
            .background(HomeStyle.screenBackground)
            .navigationTitle("バックアップ復元")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ManualRestoreSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(HomeStyle.textPrimary)
            Spacer(minLength: 0)
            Text(value)
                .font(AppTypography.body)
                .foregroundColor(HomeStyle.textSecondary)
        }
    }
}
