import Foundation
import DDDKit

/// 可被單次兌換、綁定 PKCE 的短效 code（例如 authorization code）。
///
/// `markDelete()`（swift-ddd-kit 的預設實作）會 append 此 aggregate 的 deleted event（`DeletedEventType`）：
/// `SingleUseCodeRedeemer` 靠寫入這個事件完成兌換，並靠 `find(byId:)` 隱藏帶有它的 aggregate 讓已兌換的 code 回 `.notFound`。
/// 實作者的 `when(event:)` 收到 deleted event 時必須呼叫 `metadata.delete()`。
public protocol SingleUseCode: AggregateRoot {
    var expiresAt: Date { get }
    /// S256 的 code challenge
    var codeChallenge: String { get }
}

public enum SingleUseCodeError: Error, Equatable, Sendable {
    case notFound, expired, challengeVerifyFailed, alreadyRedeemed
}
