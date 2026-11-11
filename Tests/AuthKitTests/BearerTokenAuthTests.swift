import Testing
@testable import AuthKit

/// Transplanted from StaffContext/Tests/StaffContextSharedTests/BearerTokenAuthTests.swift
/// gRPC 共享 bearer token 的授權決策。契約與 IAMContext 一致
/// （見 `IAMContext/docs/grpc-auth-contract.md`）：接受 `Bearer <token>` 或裸 token、
/// scheme 大小寫不敏感、比較為常數時間。
@Suite("BearerTokenAuth")
struct BearerTokenAuthTests {

    private let expected = "s3cr3t-token"

    // MARK: - 放行

    @Test("帶 Bearer 前綴且 token 相符 → authorized")
    func bearerPrefixed() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["Bearer \(expected)"], expectedToken: expected) == .authorized)
    }

    @Test("裸 token（無 Bearer 前綴）亦接受")
    func bareToken() {
        #expect(BearerTokenAuth.decide(authorizationValues: [expected], expectedToken: expected) == .authorized)
    }

    @Test("scheme 大小寫不敏感", arguments: ["bearer", "BEARER", "BeArEr"])
    func schemeCaseInsensitive(scheme: String) {
        #expect(BearerTokenAuth.decide(authorizationValues: ["\(scheme) \(expected)"], expectedToken: expected) == .authorized)
    }

    @Test("前後空白不影響判定")
    func surroundingWhitespace() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["  Bearer   \(expected)  "], expectedToken: expected) == .authorized)
    }

    @Test("多個 authorization 值時取第一個非空者")
    func picksFirstNonEmpty() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["", "   ", "Bearer \(expected)"], expectedToken: expected) == .authorized)
    }

    // MARK: - 缺少（missing）

    @Test("完全沒帶 authorization → missing")
    func noHeader() {
        #expect(BearerTokenAuth.decide(authorizationValues: [], expectedToken: expected) == .missing)
    }

    @Test("帶了但全為空白 → missing（而非 invalid）")
    func blankHeaders() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["", "   "], expectedToken: expected) == .missing)
    }

    // MARK: - 不符（invalid）

    @Test("token 不符 → invalid")
    func wrongToken() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["Bearer wrong"], expectedToken: expected) == .invalid)
    }

    @Test("token 為 expected 的前綴 → invalid（不可只比前綴）")
    func prefixIsNotEnough() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["Bearer s3cr3t"], expectedToken: expected) == .invalid)
    }

    @Test("大小寫不同的 token → invalid（只有 scheme 不分大小寫，token 本身分）")
    func tokenIsCaseSensitive() {
        #expect(BearerTokenAuth.decide(authorizationValues: ["Bearer S3CR3T-TOKEN"], expectedToken: expected) == .invalid)
    }

    // MARK: - 常數時間比較的正確性
    //
    // 無法在單元測試中可靠地驗「時間」是否恆定（會受排程雜訊影響），
    // 但可以驗它作為比較函數的**正確性**——長度不同、空字串等邊界。

    @Test("常數時間比較：相同字串為真")
    func constantTimeEqual() {
        #expect(BearerTokenAuth.constantTimeEquals("abc", "abc"))
    }

    @Test("常數時間比較：長度不同必為假")
    func constantTimeDifferentLength() {
        #expect(!BearerTokenAuth.constantTimeEquals("abc", "abcd"))
        #expect(!BearerTokenAuth.constantTimeEquals("abcd", "abc"))
    }

    @Test("常數時間比較：兩者皆空為真，單邊空為假")
    func constantTimeEmpty() {
        #expect(BearerTokenAuth.constantTimeEquals("", ""))
        #expect(!BearerTokenAuth.constantTimeEquals("", "a"))
        #expect(!BearerTokenAuth.constantTimeEquals("a", ""))
    }

    @Test("stripBearerScheme：非 Bearer 開頭原樣回傳")
    func stripKeepsNonBearer() {
        #expect(BearerTokenAuth.stripBearerScheme("Basic abc") == "Basic abc")
    }

    // MARK: - IAMContext extra case
    // Transplanted from IAMContext/Tests/IAMContextTests/BearerTokenAuthTests.swift
    @Test("invalid_when_token_is_prefix_of_expected")
    func invalidWhenTokenIsPrefixOfExpected() {
        // 防「前綴即通過」：presented 是 expected 的前綴也必須 invalid。
        let token = "s3cr3t-shared-token"
        #expect(BearerTokenAuth.decide(authorizationValues: ["Bearer s3cr3t"], expectedToken: token) == .invalid)
    }
}
