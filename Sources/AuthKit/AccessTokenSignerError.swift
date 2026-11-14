/// `AccessTokenSigner` 的錯誤。associated value 不會帶任何金鑰材料。
public enum AccessTokenSignerError: Error, Equatable, Sendable {
    // init
    /// 不是 JSON 物件,或必要欄位不是字串
    case malformedJWK
    /// kty != "RSA"
    case notRSA
    /// 沒有 kid 或是空字串
    case missingKid
    /// JWK 沒有 d
    case publicKeyOnly
    /// n/e/d/p/q 缺漏或無法 base64url 解碼、swift-crypto 拒收、PEM 不是 RSA 私鑰
    case invalidKey
    case keyTooSmall(bits: Int)
    // sign
    case wildcardScopeInDelegatedToken
    case invalidScopeToken(String)
    case actorsNotAllowedForApplication
    case emptyAudience
    case nonPositiveLifetime
}
