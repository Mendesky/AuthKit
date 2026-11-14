import Foundation
import _CryptoExtras

/// 以 RS256 簽發 RFC 9068 `at+jwt` access token。無狀態,只依賴 swift-crypto。
public struct AccessTokenSigner: Sendable {
    public static let minimumModulusBits = 2048

    public let kid: String
    private let privateKey: _RSA.Signing.PrivateKey

    /// 從 RSA 私鑰 JWK(RFC 7517/7518)建立。必須帶 `kid`、`n/e/d/p/q`。
    public init(signingKeyJWK: Data) throws {
        guard let jwk = try? JSONDecoder().decode(PrivateJWK.self, from: signingKeyJWK) else {
            throw AccessTokenSignerError.malformedJWK
        }
        guard jwk.kty == "RSA" else { throw AccessTokenSignerError.notRSA }
        guard let kid = jwk.kid, !kid.isEmpty else { throw AccessTokenSignerError.missingKid }
        guard jwk.d != nil else { throw AccessTokenSignerError.publicKeyOnly }
        guard let n = jwk.n.flatMap(Base64URL.decode),
              let e = jwk.e.flatMap(Base64URL.decode),
              let d = jwk.d.flatMap(Base64URL.decode),
              let p = jwk.p.flatMap(Base64URL.decode),
              let q = jwk.q.flatMap(Base64URL.decode)
        else { throw AccessTokenSignerError.invalidKey }

        // 在建立 swift-crypto key 之前檢查,讓小金鑰一定得到 .keyTooSmall
        try Self.requireMinimumModulusBits(Self.modulusBits(n))

        let key: _RSA.Signing.PrivateKey
        do {
            key = try _RSA.Signing.PrivateKey(n: n, e: e, d: d, p: p, q: q)
        } catch {
            throw AccessTokenSignerError.invalidKey
        }
        try self.init(privateKey: key, kid: kid)
    }

    /// 從 RSA 私鑰 PEM(PKCS#8 或 PKCS#1)建立,kid 由呼叫端明確提供。
    /// 用 unsafe 版本解析以接受小金鑰,讓 `.keyTooSmall` 由共用的精確 bit 數檢查判斷。
    public init(signingKeyPEM: String, kid: String) throws {
        let key: _RSA.Signing.PrivateKey
        do {
            key = try _RSA.Signing.PrivateKey(unsafePEMRepresentation: signingKeyPEM)
        } catch {
            throw AccessTokenSignerError.invalidKey
        }
        try self.init(privateKey: key, kid: kid)
    }

    /// 共用的 kid 與 bit 數檢查(PEM 路徑也走這裡)。
    init(privateKey: _RSA.Signing.PrivateKey, kid: String) throws {
        guard !kid.isEmpty else { throw AccessTokenSignerError.missingKid }
        let modulus = try privateKey.publicKey.getKeyPrimitives().modulus
        try Self.requireMinimumModulusBits(Self.modulusBits(modulus))
        self.privateKey = privateKey
        self.kid = kid
    }

    /// modulus 去掉前導 0 之後的精確 bit 數(不是 byte 對齊的 `keySizeInBits`)。
    static func modulusBits(_ n: Data) -> Int {
        let bytes = Array(n.drop(while: { $0 == 0 }))
        guard let lead = bytes.first else { return 0 }
        return (bytes.count - 1) * 8 + (8 - lead.leadingZeroBitCount)
    }

    private static func requireMinimumModulusBits(_ bits: Int) throws {
        guard bits >= minimumModulusBits else {
            throw AccessTokenSignerError.keyTooSmall(bits: bits)
        }
    }

    private struct PrivateJWK: Decodable {
        let kty: String?
        let kid: String?
        let n: String?
        let e: String?
        let d: String?
        let p: String?
        let q: String?
    }
}
