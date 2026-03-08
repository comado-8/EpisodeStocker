import Foundation

struct DecodedManualBackup {
    let manifest: ManualBackupManifest
    let payload: ManualBackupPayloadV1
}

struct ManualBackupFileCodec {
    static let currentSchemaVersion = 1
    static let algorithmIdentifier = "AES-GCM"
    static let keyDerivationIdentifier = "PBKDF2-HMAC-SHA256"

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    func encode(
        payload: ManualBackupPayloadV1,
        passphrase: String,
        appVersion: String?,
        createdAt: Date
    ) throws -> Data {
        let payloadData: Data
        do {
            payloadData = try encoder.encode(payload)
        } catch {
            throw ManualBackupError.invalidFormat
        }

        let manifest = ManualBackupManifest(
            schemaVersion: Self.currentSchemaVersion,
            createdAt: createdAt,
            appVersion: appVersion
        )
        let associatedData = try Self.makeManifestAssociatedData(manifest)
        let ciphertext = try ManualBackupCrypto.encrypt(
            plaintext: payloadData,
            passphrase: passphrase,
            associatedData: associatedData
        )
        let envelope = ManualBackupEnvelope(
            manifest: manifest,
            encryption: ManualBackupEncryptionInfo(
                algorithm: Self.algorithmIdentifier,
                keyDerivation: Self.keyDerivationIdentifier,
                iterations: ciphertext.iterations,
                salt: ciphertext.salt
            ),
            sealedBoxCombined: ciphertext.sealedBoxCombined
        )

        do {
            return try encoder.encode(envelope)
        } catch {
            throw ManualBackupError.invalidFormat
        }
    }

    func decode(_ data: Data, passphrase: String) throws -> DecodedManualBackup {
        let envelope: ManualBackupEnvelope
        do {
            envelope = try decoder.decode(ManualBackupEnvelope.self, from: data)
        } catch {
            throw ManualBackupError.invalidFormat
        }

        switch envelope.manifest.schemaVersion {
        case Self.currentSchemaVersion:
            break
        default:
            throw ManualBackupError.unsupportedVersion(envelope.manifest.schemaVersion)
        }

        guard envelope.encryption.algorithm == Self.algorithmIdentifier,
              envelope.encryption.keyDerivation == Self.keyDerivationIdentifier
        else {
            throw ManualBackupError.invalidFormat
        }

        let plaintext: Data
        do {
            let associatedData = try Self.makeManifestAssociatedData(envelope.manifest)
            plaintext = try ManualBackupCrypto.decrypt(
                ciphertext: ManualBackupCiphertext(
                    salt: envelope.encryption.salt,
                    iterations: envelope.encryption.iterations,
                    sealedBoxCombined: envelope.sealedBoxCombined
                ),
                passphrase: passphrase,
                associatedData: associatedData
            )
        } catch let error as ManualBackupError {
            if error == .decryptFailed {
                throw ManualBackupError.wrongPassphrase
            }
            throw error
        } catch let error {
            throw error
        }

        let payload: ManualBackupPayloadV1
        do {
            payload = try decoder.decode(ManualBackupPayloadV1.self, from: plaintext)
        } catch {
            throw ManualBackupError.invalidFormat
        }

        return DecodedManualBackup(manifest: envelope.manifest, payload: payload)
    }

    private static func makeManifestAssociatedData(_ manifest: ManualBackupManifest) throws -> Data {
        guard let schemaVersion = Int64(exactly: manifest.schemaVersion) else {
            throw ManualBackupError.invalidFormat
        }
        var data = Data("EpisodeStockerManualBackupManifestV1".utf8)
        data.appendFixedWidthInteger(schemaVersion)
        data.appendFixedWidthInteger(manifest.createdAt.timeIntervalSince1970.bitPattern)
        if let appVersion = manifest.appVersion {
            data.append(1)
            let versionData = Data(appVersion.utf8)
            data.appendFixedWidthInteger(UInt32(versionData.count))
            data.append(versionData)
        } else {
            data.append(0)
        }
        return data
    }
}

private extension Data {
    mutating func appendFixedWidthInteger<T: FixedWidthInteger>(_ value: T) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { rawBuffer in
            append(rawBuffer.bindMemory(to: UInt8.self))
        }
    }
}
