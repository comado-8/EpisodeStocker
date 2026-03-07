import Foundation

struct DecodedManualBackup {
    let manifest: ManualBackupManifest
    let payload: ManualBackupPayloadV1
}

struct ManualBackupFileCodec {
    static let currentSchemaVersion = 1

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: () -> Date

    init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        now: @escaping () -> Date = Date.init
    ) {
        self.encoder = encoder
        self.decoder = decoder
        self.now = now
    }

    func encode(
        payload: ManualBackupPayloadV1,
        passphrase: String,
        appVersion: String?
    ) throws -> Data {
        let payloadData: Data
        do {
            payloadData = try encoder.encode(payload)
        } catch {
            throw ManualBackupError.invalidFormat
        }

        let ciphertext = try ManualBackupCrypto.encrypt(plaintext: payloadData, passphrase: passphrase)
        let envelope = ManualBackupEnvelope(
            manifest: ManualBackupManifest(
                schemaVersion: Self.currentSchemaVersion,
                createdAt: now(),
                appVersion: appVersion
            ),
            encryption: ManualBackupEncryptionInfo(
                algorithm: "AES-GCM",
                keyDerivation: "PBKDF2-HMAC-SHA256",
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

        guard envelope.encryption.algorithm == "AES-GCM",
              envelope.encryption.keyDerivation == "PBKDF2-HMAC-SHA256"
        else {
            throw ManualBackupError.invalidFormat
        }

        let plaintext: Data
        do {
            plaintext = try ManualBackupCrypto.decrypt(
                ciphertext: ManualBackupCiphertext(
                    salt: envelope.encryption.salt,
                    iterations: envelope.encryption.iterations,
                    sealedBoxCombined: envelope.sealedBoxCombined
                ),
                passphrase: passphrase
            )
        } catch let error as ManualBackupError {
            if error == .decryptFailed {
                throw ManualBackupError.wrongPassphrase
            }
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
}
