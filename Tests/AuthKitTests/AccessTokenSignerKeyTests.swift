import Testing
import Foundation
@testable import AuthKit

@Suite("AccessTokenSigner key loading")
struct AccessTokenSignerKeyTests {
    @Test func acceptsRSA2048PrivateJWK() throws {
        let signer = try AccessTokenSigner(signingKeyJWK: try loadFixture("rsa-2048.jwk.json"))
        #expect(signer.kid == "test-2048")
    }

    @Test func rejectsMissingKid() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["kid"] = nil
        #expect(throws: AccessTokenSignerError.missingKid) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
        jwk["kid"] = ""
        #expect(throws: AccessTokenSignerError.missingKid) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    @Test func rejectsNonRSA() throws {
        let ec: [String: Any] = ["kty": "EC", "crv": "P-256", "kid": "ec-1", "x": "AA", "y": "AA", "d": "AA"]
        #expect(throws: AccessTokenSignerError.notRSA) { try AccessTokenSigner(signingKeyJWK: try jwkData(ec)) }
    }

    @Test func rejectsKeySmallerThan2048Bits() {
        #expect(throws: AccessTokenSignerError.keyTooSmall(bits: 1024)) {
            try AccessTokenSigner(signingKeyJWK: try loadFixture("rsa-1024.jwk.json"))
        }
    }

    @Test func rejectsPublicOnlyJWK() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json")
        for k in ["d", "p", "q", "dp", "dq", "qi"] { jwk[k] = nil }
        #expect(throws: AccessTokenSignerError.publicKeyOnly) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    @Test func rejectsPrivateExponentWithoutPrimes() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["p"] = nil; jwk["q"] = nil
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: AccessTokenSignerError.malformedJWK) { try AccessTokenSigner(signingKeyJWK: Data("not json".utf8)) }
        #expect(throws: AccessTokenSignerError.malformedJWK) { try AccessTokenSigner(signingKeyJWK: Data("[]".utf8)) }
    }

    @Test func rejectsUndecodableModulus() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["n"] = "!!!"
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    // F2: modulus 位元數要精確,不是 byte 對齊
    @Test func modulusBitsIsExact() {
        #expect(AccessTokenSigner.modulusBits(Data([0x00, 0xFF, 0xFF])) == 16)
        #expect(AccessTokenSigner.modulusBits(Data([0x7F] + [UInt8](repeating: 0xFF, count: 255))) == 2047)
        #expect(AccessTokenSigner.modulusBits(Data([0x80] + [UInt8](repeating: 0, count: 255))) == 2048)
        #expect(AccessTokenSigner.modulusBits(Data()) == 0)
    }

    @Test func rejects2047BitModulus() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json")
        // 2047 bit 的 n(內容不必是合法 RSA modulus;bit 檢查在建 key 之前)
        let n = Data([0x7F] + [UInt8](repeating: 0xFF, count: 255))
        jwk["n"] = Base64URL.encode(n)
        #expect(throws: AccessTokenSignerError.keyTooSmall(bits: 2047)) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }
}
