import Foundation
import XCTest
@testable import EpisodeStocker

final class ManualBackupFileCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let codec = ManualBackupFileCodec(now: { now })
        let payload = makePayload()

        let encoded = try codec.encode(
            payload: payload,
            passphrase: "backup-passphrase",
            appVersion: "1.0.0"
        )
        let decoded = try codec.decode(encoded, passphrase: "backup-passphrase")

        XCTAssertEqual(decoded.manifest.schemaVersion, ManualBackupFileCodec.currentSchemaVersion)
        XCTAssertEqual(decoded.manifest.createdAt, now)
        XCTAssertEqual(decoded.manifest.appVersion, "1.0.0")
        XCTAssertEqual(decoded.payload, payload)
    }

    func testDecodeWithWrongPassphraseThrowsWrongPassphrase() throws {
        let codec = ManualBackupFileCodec()
        let encoded = try codec.encode(
            payload: makePayload(),
            passphrase: "correct-passphrase",
            appVersion: "1.0.0"
        )

        XCTAssertThrowsError(try codec.decode(encoded, passphrase: "wrong-passphrase")) { error in
            XCTAssertEqual(error as? ManualBackupError, .wrongPassphrase)
        }
    }

    func testDecodeWithUnsupportedVersionThrowsUnsupportedVersion() throws {
        let codec = ManualBackupFileCodec()
        let encoded = try codec.encode(
            payload: makePayload(),
            passphrase: "backup-passphrase",
            appVersion: "1.0.0"
        )

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var manifest = try XCTUnwrap(json["manifest"] as? [String: Any])
        manifest["schemaVersion"] = 2
        json["manifest"] = manifest
        let modified = try JSONSerialization.data(withJSONObject: json, options: [])

        XCTAssertThrowsError(try codec.decode(modified, passphrase: "backup-passphrase")) { error in
            XCTAssertEqual(error as? ManualBackupError, .unsupportedVersion(2))
        }
    }

    func testDecodeWithTooLargeIterationsThrowsInvalidFormat() throws {
        let codec = ManualBackupFileCodec()
        let encoded = try codec.encode(
            payload: makePayload(),
            passphrase: "backup-passphrase",
            appVersion: "1.0.0"
        )

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var encryption = try XCTUnwrap(json["encryption"] as? [String: Any])
        encryption["iterations"] = Int.max
        json["encryption"] = encryption
        let modified = try JSONSerialization.data(withJSONObject: json, options: [])

        XCTAssertThrowsError(try codec.decode(modified, passphrase: "backup-passphrase")) { error in
            XCTAssertEqual(error as? ManualBackupError, .invalidFormat)
        }
    }

    private func makePayload() -> ManualBackupPayloadV1 {
        let episodeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let unlockLogID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let tagID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let personID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let projectID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let emotionID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let placeID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let date = Date(timeIntervalSince1970: 100)

        return ManualBackupPayloadV1(
            episodes: [
                .init(
                    id: episodeID,
                    date: date,
                    title: "sample",
                    body: "body",
                    unlockDate: nil,
                    type: "type",
                    createdAt: date,
                    updatedAt: date,
                    isSoftDeleted: false,
                    deletedAt: nil,
                    tagIDs: [tagID],
                    personIDs: [personID],
                    projectIDs: [projectID],
                    emotionIDs: [emotionID],
                    placeIDs: [placeID]
                )
            ],
            unlockLogs: [
                .init(
                    id: unlockLogID,
                    talkedAt: date,
                    mediaPublicAt: nil,
                    mediaType: "配信",
                    projectNameText: "name",
                    reaction: "ウケた",
                    memo: "memo",
                    createdAt: date,
                    updatedAt: date,
                    isSoftDeleted: false,
                    deletedAt: nil,
                    episodeID: episodeID
                )
            ],
            tags: [.init(id: tagID, name: "tag", nameNormalized: "tag", createdAt: date, updatedAt: date, isSoftDeleted: false, deletedAt: nil)],
            persons: [.init(id: personID, name: "person", nameNormalized: "person", createdAt: date, updatedAt: date, isSoftDeleted: false, deletedAt: nil)],
            projects: [.init(id: projectID, name: "project", nameNormalized: "project", createdAt: date, updatedAt: date, isSoftDeleted: false, deletedAt: nil)],
            emotions: [.init(id: emotionID, name: "emotion", nameNormalized: "emotion", createdAt: date, updatedAt: date, isSoftDeleted: false, deletedAt: nil)],
            places: [.init(id: placeID, name: "place", nameNormalized: "place", createdAt: date, updatedAt: date, isSoftDeleted: false, deletedAt: nil)]
        )
    }
}
