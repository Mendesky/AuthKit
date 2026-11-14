import Foundation
import _CryptoExtras

/// 以 RS256 簽發 RFC 9068 `at+jwt` access token。無狀態，只依賴 swift-crypto。
public struct AccessTokenSigner: Sendable {
    public static let minimumModulusBits = 2048

    public let kid: String
    private let privateKey: _RSA.Signing.PrivateKey

    /// 從 RSA 私鑰 JWK（RFC 7517/7518）建立。必須帶 `kid`、`n/e/d/p/q`。
    public init(signingKeyJWK: Data) throws {
        guard let jwk = try? JSONDecoder().decode(PrivateJWK.self, from: signingKeyJWK) else {
            throw AccessTokenSignerError.malformedJWK
        }
        guard jwk.kty == "RSA" else { throw AccessTokenSignerError.notRSA }
        guard let kid = jwk.kid else { throw AccessTokenSignerError.missingKid }
        guard jwk.d != nil else { throw AccessTokenSignerError.publicKeyOnly }
        // RFC 7517：有宣告 alg／use 時必須與本 signer 的用途一致（RS256／sig）。
        if let alg = jwk.alg, alg != "RS256" { throw AccessTokenSignerError.invalidKey }
        if let use = jwk.use, use != "sig" { throw AccessTokenSignerError.invalidKey }
        guard let n = jwk.n.flatMap(Base64URL.decode),
              let e = jwk.e.flatMap(Base64URL.decode),
              let d = jwk.d.flatMap(Base64URL.decode),
              let p = jwk.p.flatMap(Base64URL.decode),
              let q = jwk.q.flatMap(Base64URL.decode)
        else { throw AccessTokenSignerError.invalidKey }

        // 在建立 swift-crypto key 之前檢查，讓小金鑰一定得到 .keyTooSmall
        try Self.requireMinimumModulusBits(Self.modulusBits(n))

        let key: _RSA.Signing.PrivateKey
        do {
            key = try _RSA.Signing.PrivateKey(n: n, e: e, d: d, p: p, q: q)
        } catch {
            throw AccessTokenSignerError.invalidKey
        }
        try self.init(privateKey: key, kid: kid)
    }

    /// 從 RSA 私鑰 PEM（PKCS#8 或 PKCS#1）建立，kid 由呼叫端明確提供。
    /// 用 unsafe 版本解析以接受小金鑰，讓 `.keyTooSmall` 由共用的精確 bit 數檢查判斷。
    public init(signingKeyPEM: String, kid: String) throws {
        let key: _RSA.Signing.PrivateKey
        do {
            key = try _RSA.Signing.PrivateKey(unsafePEMRepresentation: signingKeyPEM)
        } catch {
            throw AccessTokenSignerError.invalidKey
        }
        try self.init(privateKey: key, kid: kid)
    }

    /// 共用的 kid 與 bit 數檢查（JWK、PEM 路徑都走這裡）。
    /// kid 規則與 Middleware 的 trust 一致：非空，且每個 UTF-8 byte 都在 0x21...0x7E、不是 `"`（0x22）或 `\`（0x5C）。
    init(privateKey: _RSA.Signing.PrivateKey, kid: String) throws {
        guard !kid.isEmpty,
              kid.utf8.allSatisfy({ (0x21...0x7E).contains($0) && $0 != 0x22 && $0 != 0x5C })
        else { throw AccessTokenSignerError.missingKid }
        let modulus = try privateKey.publicKey.getKeyPrimitives().modulus
        try Self.requireMinimumModulusBits(Self.modulusBits(modulus))
        self.privateKey = privateKey
        self.kid = kid
    }

    /// 簽發 RS256 `at+jwt`。`now` 的小數秒會捨去，`exp = iat + lifetime 的整秒部分`。
    public func sign(_ claims: AccessTokenClaims, now: Date = .now) throws -> String {
        try claims.validate()

        // 公開的錯誤 enum 已固定、不新增 case，所以 `now` 無法表示成整數秒與 exp 溢位這兩種
        // 實務上不可能發生的情況，都借用 `.nonPositiveLifetime`（語意：算不出合法的 exp）。
        guard let iat = Int(exactly: now.timeIntervalSince1970.rounded(.down)) else {
            throw AccessTokenSignerError.nonPositiveLifetime
        }
        let (exp, overflow) = iat.addingReportingOverflow(Int(claims.lifetime.components.seconds))
        guard !overflow else { throw AccessTokenSignerError.nonPositiveLifetime }

        var jtiBytes = [UInt8](repeating: 0, count: 16)
        var rng = SystemRandomNumberGenerator()
        for i in jtiBytes.indices { jtiBytes[i] = rng.next() }

        let payload = Payload(
            iss: claims.issuer, sub: claims.subject, sub_type: claims.subjectType.rawValue,
            act: claims.actors.reversed().reduce(nil) { ActorClaim(sub: $1, act: $0) },
            client_id: claims.clientId, aud: claims.audience, scope: claims.scope.joined(separator: " "),
            sid: claims.sessionId, iat: iat, exp: exp, jti: Base64URL.encode(Data(jtiBytes)))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let header = Base64URL.encode(try encoder.encode(Header(alg: "RS256", typ: "at+jwt", kid: kid)))
        let body = Base64URL.encode(try encoder.encode(payload))
        let signingInput = "\(header).\(body)"
        let signature = try privateKey.signature(for: Data(signingInput.utf8), padding: .insecurePKCS1v1_5)
        return "\(signingInput).\(Base64URL.encode(signature.rawRepresentation))"
    }

    /// modulus 去掉前導 0 之後的精確 bit 數（不是 byte 對齊的 `keySizeInBits`）。
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
        let alg: String?
        let use: String?
        let n: String?
        let e: String?
        let d: String?
        let p: String?
        let q: String?
    }

    private struct Header: Encodable {
        let alg: String
        let typ: String
        let kid: String
    }

    /// RFC 8693 巢狀 act；最內層的 `act` 為 nil，由合成的 `encodeIfPresent` 省略。
    private final class ActorClaim: Encodable {
        let sub: String
        let act: ActorClaim?
        init(sub: String, act: ActorClaim?) { self.sub = sub; self.act = act }
    }

    private struct Payload: Encodable {
        let iss: String
        let sub: String
        let sub_type: String
        let act: ActorClaim?
        let client_id: String
        let aud: [String]
        let scope: String
        let sid: String?
        let iat: Int
        let exp: Int
        let jti: String
    }
}
