/// RFC 9068 access token 的 claims 輸入。`iat`/`exp`/`jti` 由 `AccessTokenSigner.sign` 產生。
public struct AccessTokenClaims: Sendable, Equatable {
    public enum SubjectType: String, Sendable, Equatable { case user, application }

    public let issuer: String
    public let subject: String
    public let subjectType: SubjectType
    /// act 鏈,由外到內(最外層是目前代為呼叫的一方);空陣列 = 非代理 token。
    public let actors: [String]
    public let clientId: String
    public let audience: [String]
    public let scope: [String]
    /// `sid`;nil 時整個欄位省略。
    public let sessionId: String?
    public let lifetime: Duration

    public init(issuer: String, subject: String, subjectType: SubjectType, actors: [String] = [],
                clientId: String, audience: [String], scope: [String], sessionId: String? = nil,
                lifetime: Duration) {
        self.issuer = issuer
        self.subject = subject
        self.subjectType = subjectType
        self.actors = actors
        self.clientId = clientId
        self.audience = audience
        self.scope = scope
        self.sessionId = sessionId
        self.lifetime = lifetime
    }

    /// 簽發前的規則檢查,違反即 throw。順序:application+actors → aud → lifetime → scope token → 代理 token 的萬用字元。
    func validate() throws {
        if subjectType == .application && !actors.isEmpty {
            throw AccessTokenSignerError.actorsNotAllowedForApplication
        }
        if audience.isEmpty { throw AccessTokenSignerError.emptyAudience }
        // 整秒部分 <= 0(含小於 1 秒)會讓 token 一出生就過期。
        if lifetime.components.seconds <= 0 { throw AccessTokenSignerError.nonPositiveLifetime }
        for item in scope where !Self.isScopeToken(item) {
            throw AccessTokenSignerError.invalidScopeToken(item)
        }
        if !actors.isEmpty && scope.contains(where: { $0.contains("*") }) {
            throw AccessTokenSignerError.wildcardScopeInDelegatedToken
        }
    }

    /// RFC 6749 §3.3 `scope-token`:1 個以上 `%x21 / %x23-5B / %x5D-7E`。
    private static func isScopeToken(_ item: String) -> Bool {
        !item.isEmpty && item.utf8.allSatisfy { $0 == 0x21 || (0x23...0x5B).contains($0) || (0x5D...0x7E).contains($0) }
    }
}
