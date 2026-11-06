import Foundation
import CryptoKit
import Darwin

// Sparkle 2.10 accepts a base64-encoded 32-byte Ed25519 seed (--ed-key-file).
// Keep the file local, chmod 600, never print it or add it to a release archive.
let arguments = CommandLine.arguments
func fail(_ message: String) -> Never { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1) }
guard arguments.count >= 3 else { fail("Usage: release-signing prepare-key KEY | public-key KEY | sign KEY ARCHIVE") }
let command = arguments[1]
let keyURL = URL(fileURLWithPath: arguments[2])
do {
    if command == "prepare-key" && !FileManager.default.fileExists(atPath: keyURL.path) {
        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let seed = Curve25519.Signing.PrivateKey().rawRepresentation.base64EncodedString()
        let descriptor = open(keyURL.path, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { fail("Could not securely create signing key; existing keys are never replaced") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: Data(seed.utf8))
        try handle.close()
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: keyURL.path)
    guard let permissions = attributes[.posixPermissions] as? NSNumber, permissions.intValue & 0o077 == 0 else { fail("Signing key must not be readable by other users (chmod 600)") }
    let encoded = try String(contentsOf: keyURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let seed = Data(base64Encoded: encoded), seed.count == 32 else { fail("Invalid Ed25519 seed") }
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    if command == "prepare-key" || command == "public-key" { print(key.publicKey.rawRepresentation.base64EncodedString()) }
    else if command == "sign" && arguments.count == 4 {
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[3]), options: .mappedIfSafe)
        let signature = try key.signature(for: data)
        guard key.publicKey.isValidSignature(signature, for: data) else { fail("Signature self-verification failed") }
        print(signature.base64EncodedString())
    } else { fail("Unknown command") }
} catch { fail("Signing operation failed: \(error.localizedDescription)") }
