import Testing
@testable import AuthKit

@Suite("PKCE")
struct PKCETests {
    // RFC 7636 Appendix B test vector
    private let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    private let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    @Test("challenge matches RFC 7636 vector")
    func challengeVector() {
        #expect(PKCE.challenge(forVerifier: verifier) == challenge)
    }

    @Test("verify accepts and rejects")
    func verifyCases() {
        #expect(PKCE.verify(verifier: verifier, challenge: challenge))
        #expect(!PKCE.verify(verifier: verifier + "x", challenge: challenge))
        #expect(!PKCE.verify(verifier: "", challenge: challenge))
    }

    @Test("short verifiers still verify (first-party compatibility)")
    func shortVerifier() {
        #expect(PKCE.verify(verifier: "test-codeVerifier", challenge: PKCE.challenge(forVerifier: "test-codeVerifier")))
    }

    @Test("isValidVerifier follows RFC 7636 section 4.1")
    func validity() {
        #expect(PKCE.isValidVerifier(verifier))
        #expect(!PKCE.isValidVerifier("test-codeVerifier"))
        #expect(!PKCE.isValidVerifier(String(repeating: "a", count: 129)))
        #expect(PKCE.isValidVerifier(String(repeating: "a", count: 43)))
        #expect(PKCE.isValidVerifier(String(repeating: "a", count: 128)))
        #expect(!PKCE.isValidVerifier(String(repeating: "a", count: 42) + "+"))
    }
}
