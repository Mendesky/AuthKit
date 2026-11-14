import Testing
import Foundation
import Crypto
import _CryptoExtras
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

    @Test func rejectsJWKWithNonRS256Alg() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["alg"] = "PS256"
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    @Test func rejectsJWKWithNonSigUse() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["use"] = "enc"
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyJWK: try jwkData(jwk)) }
    }

    @Test func acceptsJWKWithRS256AlgAndSigUse() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json"); jwk["alg"] = "RS256"; jwk["use"] = "sig"
        let signer = try AccessTokenSigner(signingKeyJWK: try jwkData(jwk))
        #expect(signer.kid == "test-2048")
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

    @Test func acceptsPKCS8AndPKCS1PEM() throws {
        let pkcs8 = String(decoding: try loadFixture("rsa-2048.pem"), as: UTF8.self)
        #expect(try AccessTokenSigner(signingKeyPEM: pkcs8, kid: "pem-1").kid == "pem-1")
        let pkcs1 = try _RSA.Signing.PrivateKey(pemRepresentation: pkcs8).pemRepresentation
        #expect(pkcs1.contains("BEGIN RSA PRIVATE KEY"))
        #expect(try AccessTokenSigner(signingKeyPEM: pkcs1, kid: "pem-1").kid == "pem-1")
    }

    @Test func pemRejectsEmptyKid() throws {
        let pem = String(decoding: try loadFixture("rsa-2048.pem"), as: UTF8.self)
        #expect(throws: AccessTokenSignerError.missingKid) { try AccessTokenSigner(signingKeyPEM: pem, kid: "") }
    }

    @Test func pemRejects1024BitKey() throws {
        let pem = String(decoding: try loadFixture("rsa-1024.pem"), as: UTF8.self)
        #expect(throws: AccessTokenSignerError.keyTooSmall(bits: 1024)) { try AccessTokenSigner(signingKeyPEM: pem, kid: "k") }
    }

    @Test func pemRejectsPublicKeyAndNonRSA() throws {
        let pem = String(decoding: try loadFixture("rsa-2048.pem"), as: UTF8.self)
        let publicPEM = try _RSA.Signing.PrivateKey(pemRepresentation: pem).publicKey.pemRepresentation
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyPEM: publicPEM, kid: "k") }
        let ecPEM = P256.Signing.PrivateKey().pemRepresentation
        #expect(throws: AccessTokenSignerError.invalidKey) { try AccessTokenSigner(signingKeyPEM: ecPEM, kid: "k") }
    }
}
