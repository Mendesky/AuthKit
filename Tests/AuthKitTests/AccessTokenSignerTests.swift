import Testing
import Foundation
@testable import AuthKit

@Suite("AccessTokenSigner signing")
struct AccessTokenSignerTests {
    let signer: AccessTokenSigner
    let now = Date(timeIntervalSince1970: 1763100000)
    let firstParty = SampleClaims.firstParty
    let application = SampleClaims.application
    let delegated = SampleClaims.delegated

    init() throws {
        signer = try AccessTokenSigner(signingKeyJWK: try loadFixture("rsa-2048.jwk.json"))
    }

    private func claims(subject: String = "acc_8d1f", actors: [String] = [], audience: [String] = ["mendesky-services"],
                        scope: [String] = ["quote:read"], lifetime: Duration = .seconds(300)) -> AccessTokenClaims {
        AccessTokenClaims(issuer: "https://oidc.jwcpas.net/oidc-context", subject: subject, subjectType: .user,
                          actors: actors, clientId: "c", audience: audience, scope: scope, lifetime: lifetime)
    }

    private func rawPayload(_ jwt: String) -> String {
        String(decoding: Base64URL.decode(String(jwt.split(separator: ".")[1]))!, as: UTF8.self)
    }

    @Test func headerIsExactlyAlgTypKid() throws {
        let h = try jwtSegment(try signer.sign(firstParty, now: now), 0)
        #expect(Set(h.keys) == ["alg", "typ", "kid"])
        #expect(h["alg"] as? String == "RS256"); #expect(h["typ"] as? String == "at+jwt"); #expect(h["kid"] as? String == "test-2048")
    }

    @Test func signatureVerifiesWithPublicKeyFromFixture() throws {
        let jwk = try fixtureJWKObject("rsa-2048.jwk.json")
        let jwt = try signer.sign(delegated, now: now)
        #expect(jwt.split(separator: ".", omittingEmptySubsequences: false).count == 3)
        #expect(try verifyRS256(jwt: jwt, n: jwk["n"] as! String, e: jwk["e"] as! String))
        var parts = jwt.split(separator: ".").map(String.init)
        parts[1] = Base64URL.encode(Data("{\"sub\":\"someone-else\"}".utf8))
        #expect(try !verifyRS256(jwt: parts.joined(separator: "."), n: jwk["n"] as! String, e: jwk["e"] as! String))
    }

    @Test func pemSignerProducesVerifiableToken() throws {
        let pem = String(decoding: try loadFixture("rsa-2048.pem"), as: UTF8.self)
        let pemSigner = try AccessTokenSigner(signingKeyPEM: pem, kid: "pem-1")
        let jwk = try fixtureJWKObject("rsa-2048.jwk.json")
        let jwt = try pemSigner.sign(firstParty, now: now)
        #expect(try jwtSegment(jwt, 0)["kid"] as? String == "pem-1")
        #expect(try verifyRS256(jwt: jwt, n: jwk["n"] as! String, e: jwk["e"] as! String))
    }

    @Test func firstPartyClaims() throws {
        let p = try jwtSegment(try signer.sign(firstParty, now: now), 1)
        #expect(Set(p.keys) == ["iss", "sub", "sub_type", "client_id", "aud", "scope", "sid", "iat", "exp", "jti"])
        #expect(p["sub_type"] as? String == "user"); #expect(p["client_id"] as? String == "mendesky-first-party")
        #expect(p["aud"] as? [String] == ["mendesky-services"]); #expect(p["scope"] as? String == "*"); #expect(p["sid"] as? String == "auth_41c2")
    }

    @Test func applicationOmitsActAndSid() throws {
        let jwt = try signer.sign(application, now: now)
        let p = try jwtSegment(jwt, 1)
        #expect(Set(p.keys) == ["iss", "sub", "sub_type", "client_id", "aud", "scope", "iat", "exp", "jti"])
        #expect(p["sub_type"] as? String == "application")
        #expect(!rawPayload(jwt).contains("null"))
    }

    @Test func delegatedActIsNestedOutermostFirst() throws {
        let p = try jwtSegment(try signer.sign(delegated, now: now), 1)
        let act = try #require(p["act"] as? [String: Any])
        #expect(act["sub"] as? String == "mendesky-mcp-server")
        let inner = try #require(act["act"] as? [String: Any])
        #expect(inner["sub"] as? String == "claude-connector")
        #expect(Set(inner.keys) == ["sub"])
        #expect(p["client_id"] as? String == "mendesky-mcp-server"); #expect(p["scope"] as? String == "quote:read")
    }

    @Test func singleActorHasNoNestedAct() throws {
        let p = try jwtSegment(try signer.sign(claims(actors: ["mendesky-mcp-server"]), now: now), 1)
        let act = try #require(p["act"] as? [String: Any])
        #expect(Set(act.keys) == ["sub"])
        #expect(act["sub"] as? String == "mendesky-mcp-server")
    }

    @Test func audIsAlwaysArray() throws {
        let one = try jwtSegment(try signer.sign(claims(audience: ["mendesky-services"]), now: now), 1)
        #expect(one["aud"] is [String])
        #expect(one["aud"] as? [String] == ["mendesky-services"])
        let two = try jwtSegment(try signer.sign(claims(audience: ["a", "b"]), now: now), 1)
        #expect(two["aud"] as? [String] == ["a", "b"])
    }

    @Test func scopeIsSpaceDelimitedAndEmptyListGivesEmptyString() throws {
        let two = try jwtSegment(try signer.sign(claims(scope: ["quote:read", "quote:write"]), now: now), 1)
        #expect(two["scope"] as? String == "quote:read quote:write")
        let none = try jwtSegment(try signer.sign(claims(scope: []), now: now), 1)
        #expect(none.keys.contains("scope"))
        #expect(none["scope"] as? String == "")
    }

    @Test func expEqualsIatPlusLifetime() throws {
        let p = try jwtSegment(try signer.sign(delegated, now: now), 1)
        #expect(p["iat"] as? Int == 1763100000); #expect(p["exp"] as? Int == 1763100300)
    }

    @Test func fractionalNowIsFlooredToWholeSeconds() throws {
        let jwt = try signer.sign(firstParty, now: Date(timeIntervalSince1970: 1763100000.7))
        let p = try jwtSegment(jwt, 1)
        #expect(p["iat"] as? Int == 1763100000); #expect(p["exp"] as? Int == 1763100900)
        let raw = rawPayload(jwt)
        #expect(raw.contains("\"iat\":1763100000"))
        #expect(raw.contains("\"exp\":1763100900"))
    }

    @Test func lifetimeOverflowThrowsInsteadOfCrashing() {
        #expect(throws: AccessTokenSignerError.nonPositiveLifetime) {
            try signer.sign(claims(lifetime: .seconds(Int64.max)), now: now)
        }
    }

    @Test func jtiIsRandom22CharBase64URL() throws {
        let a = try jwtSegment(try signer.sign(firstParty, now: now), 1)["jti"] as? String
        let b = try jwtSegment(try signer.sign(firstParty, now: now), 1)["jti"] as? String
        let ja = try #require(a), jb = try #require(b)
        for jti in [ja, jb] {
            #expect(jti.range(of: "^[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil)
        }
        #expect(ja != jb)
    }

    @Test func specialCharactersAreJSONEscaped() throws {
        var jwk = try fixtureJWKObject("rsa-2048.jwk.json")
        let kid = "k/1", subject = #"a"b\c"#
        jwk["kid"] = kid
        let special = try AccessTokenSigner(signingKeyJWK: try jwkData(jwk))
        let jwt = try special.sign(claims(subject: subject), now: now)
        #expect(try jwtSegment(jwt, 0)["kid"] as? String == kid)
        #expect(try jwtSegment(jwt, 1)["sub"] as? String == subject)
        #expect(rawPayload(jwt).contains("https://oidc.jwcpas.net/oidc-context"))
    }
}
