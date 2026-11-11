/// gRPC server 的驗證模式解析（fail-closed）。
public enum GRPCAuthConfig {
    public enum Mode: Equatable, Sendable {
        case enabled(token: String)
        case disabled
        case notConfigured
    }

    /// token 非空 → `.enabled`；否則 flag 恰為 `"1"` → `.disabled`；否則 `.notConfigured`。
    public static func resolve(token: String?, disabledFlag: String?) -> Mode {
        if let token, !token.isEmpty { return .enabled(token: token) }
        if disabledFlag == "1" { return .disabled }
        return .notConfigured
    }
}
