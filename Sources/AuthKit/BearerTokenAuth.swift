import Foundation

/// 跨 context gRPC 介面的純授權決策邏輯——與傳輸無關，方便單元測試。
///
/// 同一份契約在 IAMContext / StaffContext / AccountContext 共用：
/// 接受 `Bearer <token>`（scheme 大小寫不敏感）或裸 token，比較為常數時間。
///
/// ⚠️ 這是 app-layer 驗證，**不含傳輸加密**（plaintext）。僅適用可信內網；跨不可信網段需另加 TLS。
public enum BearerTokenAuth {
    public enum Decision: Equatable, Sendable {
        case authorized
        /// 沒帶 authorization metadata（或全為空）→ UNAUTHENTICATED
        case missing
        /// 帶了但 token 不符 → UNAUTHENTICATED
        case invalid
    }

    /// 對 `authorization` metadata 的所有字串值做授權決策。
    public static func decide(authorizationValues: [String], expectedToken: String) -> Decision {
        guard let header = authorizationValues.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return .missing
        }
        return ConstantTime.equals(stripBearerScheme(header), expectedToken) ? .authorized : .invalid
    }

    /// 接受 `Bearer <token>`（scheme 大小寫不敏感）或裸 token 兩種寫法，回傳實際 token 字串。
    public static func stripBearerScheme(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let scheme = "bearer "
        if trimmed.count >= scheme.count, trimmed.prefix(scheme.count).lowercased() == scheme {
            return String(trimmed.dropFirst(scheme.count)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    /// 轉呼叫 `ConstantTime.equals`（保留既有呼叫端與測試使用的名稱）。
    public static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        ConstantTime.equals(a, b)
    }
}
