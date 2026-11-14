import Foundation
import _CryptoExtras
@testable import AuthKit

struct FixtureError: Error { let message: String }

/// 讀 `Fixtures/` 下的檔案。檔名含多個 `.`(如 `rsa-2048.jwk.json`),所以直接組路徑,不用 `url(forResource:)`。
func loadFixture(_ name: String) throws -> Data {
    guard let base = Bundle.module.resourceURL else { throw FixtureError(message: "no resourceURL") }
    return try Data(contentsOf: base.appendingPathComponent("Fixtures/\(name)"))
}

func fixtureJWKObject(_ name: String) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: try loadFixture(name)) as? [String: Any] else {
        throw FixtureError(message: "fixture \(name) is not a JSON object")
    }
    return object
}

func jwkData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
}

func decodeBase64URL(_ string: String) throws -> Data {
    var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s += "=" }
    guard let data = Data(base64Encoded: s) else { throw FixtureError(message: "bad base64url") }
    return data
}

/// 獨立驗簽:只用 swift-crypto 公鑰,不經過 AccessTokenSigner。
func verifyRS256(jwt: String, n: String, e: String) throws -> Bool {
    let parts = jwt.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3 else { throw FixtureError(message: "not a compact JWS") }
    let publicKey = try _RSA.Signing.PublicKey(n: try decodeBase64URL(n), e: try decodeBase64URL(e))
    let signature = _RSA.Signing.RSASignature(rawRepresentation: try decodeBase64URL(parts[2]))
    return publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8), padding: .insecurePKCS1v1_5)
}

/// 解 JWT 的第 index 段(0 = header、1 = payload)為 JSON 物件。
func jwtSegment(_ jwt: String, _ index: Int) throws -> [String: Any] {
    let parts = jwt.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard index < parts.count,
          let object = try JSONSerialization.jsonObject(with: try decodeBase64URL(parts[index])) as? [String: Any]
    else { throw FixtureError(message: "segment \(index) is not a JSON object") }
    return object
}

/// 三組範例 claims(spec §4),供簽發與驗證規則的測試共用。
enum SampleClaims {
    static let firstParty = AccessTokenClaims(
        issuer: "https://platform.example/identity-context", subject: "acc_8d1f", subjectType: .user,
        clientId: "mendesky-first-party", audience: ["mendesky-services"], scope: ["*"],
        sessionId: "auth_41c2", lifetime: .seconds(900))

    static let application = AccessTokenClaims(
        issuer: "https://oidc.jwcpas.net/oidc-context", subject: "3f2a9c1e-7b4d-4c1a-9e2f-0a1b2c3d4e5f",
        subjectType: .application, clientId: "client-123", audience: ["mendesky-services"], scope: ["*"],
        lifetime: .seconds(900))

    static let delegated = AccessTokenClaims(
        issuer: "https://oidc.jwcpas.net/oidc-context", subject: "acc_8d1f", subjectType: .user,
        actors: ["mendesky-mcp-server", "claude-connector"], clientId: "mendesky-mcp-server",
        audience: ["mendesky-services"], scope: ["quote:read"], lifetime: .seconds(300))
}
