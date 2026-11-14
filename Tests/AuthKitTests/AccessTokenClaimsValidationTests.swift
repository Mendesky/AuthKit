import Foundation
import Testing
@testable import AuthKit

@Suite("AccessTokenClaims validation")
struct AccessTokenClaimsValidationTests {
    let now = Date(timeIntervalSince1970: 1_763_100_000)

    func makeSigner() throws -> AccessTokenSigner {
        try AccessTokenSigner(signingKeyJWK: try loadFixture("rsa-2048.jwk.json"))
    }

    func claims(
        base: AccessTokenClaims, actors: [String]? = nil, audience: [String]? = nil,
        scope: [String]? = nil, lifetime: Duration? = nil
    ) -> AccessTokenClaims {
        AccessTokenClaims(
            issuer: base.issuer, subject: base.subject, subjectType: base.subjectType,
            actors: actors ?? base.actors, clientId: base.clientId, audience: audience ?? base.audience,
            scope: scope ?? base.scope, sessionId: base.sessionId, lifetime: lifetime ?? base.lifetime)
    }

    @Test func delegatedTokenWithWildcardScopeIsRejected() throws {
        let signer = try makeSigner()
        for scope in [["quote:read", "*"], ["*"], ["quote:*"]] {
            let c = claims(base: SampleClaims.delegated, scope: scope)
            #expect(throws: AccessTokenSignerError.wildcardScopeInDelegatedToken) { try signer.sign(c, now: now) }
        }
    }

    @Test func firstPartyAndApplicationMayUseWildcard() throws {
        let signer = try makeSigner()
        _ = try signer.sign(SampleClaims.firstParty, now: now)
        _ = try signer.sign(SampleClaims.application, now: now)
    }

    @Test func scopeTokenWithInvalidCharactersIsRejected() throws {
        let signer = try makeSigner()
        let cases: [(AccessTokenClaims, String)] = [
            (SampleClaims.delegated, "quote:read *"),
            (SampleClaims.firstParty, "a b"),
            (SampleClaims.firstParty, ""),
            (SampleClaims.firstParty, "quote\"read"),
            (SampleClaims.firstParty, "quote\\read"),
        ]
        for (base, item) in cases {
            let c = claims(base: base, scope: [item])
            #expect(throws: AccessTokenSignerError.invalidScopeToken(item)) { try signer.sign(c, now: now) }
        }
    }

    @Test func applicationWithActorsIsRejected() throws {
        let c = claims(base: SampleClaims.application, actors: ["mendesky-mcp-server"])
        #expect(throws: AccessTokenSignerError.actorsNotAllowedForApplication) { try makeSigner().sign(c, now: now) }
    }

    @Test func emptyAudienceIsRejected() throws {
        let c = claims(base: SampleClaims.firstParty, audience: [])
        #expect(throws: AccessTokenSignerError.emptyAudience) { try makeSigner().sign(c, now: now) }
    }

    @Test func nonPositiveLifetimeIsRejected() throws {
        let signer = try makeSigner()
        for lifetime in [Duration.zero, .seconds(-1), .milliseconds(500)] {
            let c = claims(base: SampleClaims.firstParty, lifetime: lifetime)
            #expect(throws: AccessTokenSignerError.nonPositiveLifetime) { try signer.sign(c, now: now) }
        }
    }
}
