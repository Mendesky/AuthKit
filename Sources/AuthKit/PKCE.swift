import Foundation
import Crypto

/// RFC 7636 PKCE（S256）。
public enum PKCE {
    /// BASE64URL(SHA256(ASCII(verifier)))，無 padding
    public static func challenge(forVerifier verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// 以常數時間比對；不檢查 verifier 的格式（既有第一方 client 使用較短的 verifier）。
    public static func verify(verifier: String, challenge: String) -> Bool {
        ConstantTime.equals(Self.challenge(forVerifier: verifier), challenge)
    }

    /// RFC 7636 §4.1：43...128 個字元，只含 A-Z a-z 0-9 - . _ ~
    public static func isValidVerifier(_ verifier: String) -> Bool {
        let bytes = Array(verifier.utf8)
        guard (43...128).contains(bytes.count) else { return false }
        return bytes.allSatisfy { b in
            (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || (b >= 0x30 && b <= 0x39)
                || b == 0x2D || b == 0x2E || b == 0x5F || b == 0x7E
        }
    }
}
