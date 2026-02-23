import Foundation
import SwiftData

@MainActor
enum SeedData {
    enum Profile {
        case minimal
        case simulatorComprehensive
    }

    static func seedIfNeeded(context: ModelContext, profile: Profile = .minimal) {
        let descriptor = FetchDescriptor<Episode>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        switch profile {
        case .minimal:
            insertMinimalSample(context: context)
        case .simulatorComprehensive:
            insertComprehensiveSimulatorSamples(context: context)
        }
    }

    private static func insertMinimalSample(context: ModelContext) {
        let now = Date()
        _ = context.createEpisode(
            title: "初期サンプル: 収録前の出来事",
            body: "収録直前に起きた小ネタをここに書く",
            date: now,
            unlockDate: nil,
            type: nil,
            tags: ["#仕事"],
            persons: ["田中さん"],
            projects: ["朝の番組"],
            emotions: ["嬉しかった"],
            place: "スタジオ"
        )
    }

    private static func insertComprehensiveSimulatorSamples(context: ModelContext) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let samples: [EpisodeSeedInput] = [
            .init(
                dayOffset: -12,
                title: "朝番組の導入トーク案",
                body: "自己紹介のあとに使える小ネタを3つメモ。",
                unlockOffsetDays: nil,
                type: "会話ネタ",
                tags: ["#仕事", "#番組", "#雑談"],
                persons: ["田中さん", "佐藤さん"],
                projects: ["朝の番組"],
                emotions: ["楽しかった"],
                place: "スタジオ"
            ),
            .init(
                dayOffset: -10,
                title: "移動中に思いついた企画",
                body: "電車内でメモした新コーナー案。",
                unlockOffsetDays: 3,
                type: "アイデア",
                tags: ["#企画", "#移動", "#アイデア"],
                persons: ["鈴木さん"],
                projects: ["ラジオ企画"],
                emotions: ["嬉しかった"],
                place: "渋谷"
            ),
            .init(
                dayOffset: -8,
                title: "ライブ配信の失敗学",
                body: "音声トラブル時のリカバリー手順。",
                unlockOffsetDays: nil,
                type: "学び",
                tags: ["#配信", "#トラブル", "#学び"],
                persons: ["山田さん"],
                projects: ["夜のトーク"],
                emotions: ["悔しかった"],
                place: "自宅"
            ),
            .init(
                dayOffset: -6,
                title: "打ち合わせで拾った一言",
                body: "場を和ませる短いエピソード。",
                unlockOffsetDays: -1,
                type: "会話ネタ",
                tags: ["#会話", "#仕事"],
                persons: ["田中さん", "高橋さん"],
                projects: ["朝の番組"],
                emotions: ["楽しかった"],
                place: "会議室"
            ),
            .init(
                dayOffset: -4,
                title: "炎上を避ける言い回しメモ",
                body: "誤解されやすい表現を避けるチェックリスト。",
                unlockOffsetDays: 14,
                type: "トラブル",
                tags: ["#SNS", "#危機管理", "#学び"],
                persons: ["佐藤さん"],
                projects: ["配信改善プロジェクト"],
                emotions: ["緊張した"],
                place: "オフィス"
            ),
            .init(
                dayOffset: -3,
                title: "収録後の反省会",
                body: "次回に向けた改善点を整理。",
                unlockOffsetDays: nil,
                type: "学び",
                tags: ["#反省", "#仕事", "#収録"],
                persons: ["鈴木さん", "伊藤さん"],
                projects: ["夜のトーク"],
                emotions: ["前向き"],
                place: "カフェ"
            ),
            .init(
                dayOffset: -2,
                title: "公開待ちの大ネタ",
                body: "公開タイミングを調整中。",
                unlockOffsetDays: 30,
                type: "会話ネタ",
                tags: ["#未公開", "#重要", "#番組"],
                persons: ["田中さん"],
                projects: ["特番2026春"],
                emotions: ["わくわく"],
                place: "スタジオ"
            ),
            .init(
                dayOffset: -1,
                title: "ファンイベントでの出来事",
                body: "想定外の質問で盛り上がった場面。",
                unlockOffsetDays: nil,
                type: "会話ネタ",
                tags: ["#イベント", "#雑談", "#ファン"],
                persons: ["佐藤さん", "鈴木さん"],
                projects: ["イベント企画"],
                emotions: ["嬉しかった"],
                place: "ホール"
            ),
            .init(
                dayOffset: 0,
                title: "今日の収録メモ",
                body: "冒頭5分の進行を再確認。",
                unlockOffsetDays: 1,
                type: "アイデア",
                tags: ["#当日", "#仕事", "#進行"],
                persons: ["田中さん", "高橋さん"],
                projects: ["朝の番組"],
                emotions: ["緊張した"],
                place: "スタジオ"
            ),
            .init(
                dayOffset: 1,
                title: "来週企画の下書き",
                body: "3本立て構成のうち1本目の流れ。",
                unlockOffsetDays: 10,
                type: "アイデア",
                tags: ["#下書き", "#企画", "#番組"],
                persons: ["伊藤さん"],
                projects: ["新番組準備"],
                emotions: ["集中した"],
                place: "自宅"
            )
        ]

        for sample in samples {
            let date = calendar.date(byAdding: .day, value: sample.dayOffset, to: now) ?? now
            let unlockDate: Date?
            if let unlockOffsetDays = sample.unlockOffsetDays {
                unlockDate = calendar.date(byAdding: .day, value: unlockOffsetDays, to: date)
            } else {
                unlockDate = nil
            }
            _ = context.createEpisode(
                title: sample.title,
                body: sample.body,
                date: date,
                unlockDate: unlockDate,
                type: sample.type,
                tags: sample.tags,
                persons: sample.persons,
                projects: sample.projects,
                emotions: sample.emotions,
                place: sample.place
            )
        }
    }
}

private struct EpisodeSeedInput {
    let dayOffset: Int
    let title: String
    let body: String
    let unlockOffsetDays: Int?
    let type: String?
    let tags: [String]
    let persons: [String]
    let projects: [String]
    let emotions: [String]
    let place: String?
}
