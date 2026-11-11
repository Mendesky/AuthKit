import Foundation
import DDDKit

/// 可被單次兌換、綁定 PKCE 的短效 code（例如 authorization code）。
public protocol SingleUseCode: AggregateRoot {
    var expiresAt: Date { get }
    /// S256 的 code challenge
    var codeChallenge: String { get }
}

public enum SingleUseCodeError: Error, Equatable, Sendable {
    case notFound, expired, challengeVerifyFailed, alreadyRedeemed
}
