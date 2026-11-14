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

    /// 簽發前的規則檢查。規則由後續 task 補上。
    func validate() throws {}
}
