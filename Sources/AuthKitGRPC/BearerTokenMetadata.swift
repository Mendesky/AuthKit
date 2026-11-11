import GRPCCore

/// Client-side helper: builds the `authorization` metadata a caller attaches to talk
/// to a server guarded by ``BearerTokenServerInterceptor``.
public enum BearerTokenMetadata {
    /// Returns empty metadata when `token` is nil or empty; otherwise `["authorization": "Bearer <token>"]`.
    public static func authorization(token: String?) -> Metadata {
        guard let token, !token.isEmpty else { return [:] }
        return ["authorization": "Bearer \(token)"]
    }
}
