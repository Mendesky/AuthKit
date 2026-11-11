import Foundation

/// gRPC server 的驗證模式解析（fail-closed）。
public enum GRPCAuthConfig {
    public enum Mode: Equatable, Sendable {
        case enabled(token: String)
        case disabled
        case notConfigured
    }

    /// token 先去除前後空白與換行；非空 → `.enabled`（帶去除後的值）；否則 flag 恰為 `"1"` → `.disabled`；否則 `.notConfigured`。
    public static func resolve(token: String?, disabledFlag: String?) -> Mode {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return .enabled(token: trimmed) }
        if disabledFlag == "1" { return .disabled }
        return .notConfigured
    }
}
