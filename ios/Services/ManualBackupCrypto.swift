import CommonCrypto
import CryptoKit
import Foundation
import Security

struct ManualBackupCiphertext {
    let salt: Data
    let iterations: Int
    let sealedBoxCombined: Data
}

enum ManualBackupCrypto {
    static let defaultPBKDF2Iterations = 600_000
    static let maxPBKDF2Iterations = 2_000_000
    private static let keySizeInBytes = 32
    private static let saltSizeInBytes = 16

    static func encrypt(
        plaintext: Data,
        passphrase: String,
        iterations: Int = defaultPBKDF2Iterations
    ) throws -> ManualBackupCiphertext {
        let salt = try makeRandomData(count: saltSizeInBytes)
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)

        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealedBox.combined else {
                throw ManualBackupError.encryptFailed
            }
            return ManualBackupCiphertext(
                salt: salt,
                iterations: iterations,
                sealedBoxCombined: combined
            )
        } catch {
            throw ManualBackupError.encryptFailed
        }
    }

    static func decrypt(
        ciphertext: ManualBackupCiphertext,
        passphrase: String
    ) throws -> Data {
        let key = try deriveKey(
            passphrase: passphrase,
            salt: ciphertext.salt,
            iterations: ciphertext.iterations
        )

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: ciphertext.sealedBoxCombined)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw ManualBackupError.decryptFailed
        }
    }

    private static func deriveKey(
        passphrase: String,
        salt: Data,
        iterations: Int
    ) throws -> SymmetricKey {
        guard iterations > 0,
              iterations <= maxPBKDF2Iterations,
              let validatedIterations = UInt32(exactly: iterations)
        else {
            throw ManualBackupError.invalidFormat
        }

        var derivedData = Data(repeating: 0, count: keySizeInBytes)
        let passwordData = Data(passphrase.utf8)

        let status = derivedData.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        validatedIterations,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keySizeInBytes
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw ManualBackupError.encryptFailed
        }

        return SymmetricKey(data: derivedData)
    }

    private static func makeRandomData(count: Int) throws -> Data {
        var data = Data(repeating: 0, count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }

        guard status == errSecSuccess else {
            throw ManualBackupError.encryptFailed
        }

        return data
    }
}
