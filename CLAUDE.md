# CLAUDE.md

## 用途

AuthKit 是供各 Context 微服務共用的 Swift 套件，只放**無狀態的授權邏輯**。library target 不放事件定義與資料模型（測試用的 aggregate 只放在測試 target）。
Swift tools 6.0、macOS 15+、`swiftLanguageModes: [.v5]`。

AuthKit 是 library：`Package.resolved` 不納入版本控制（已列入 `.gitignore`）。

## Targets

- **AuthKit** — 無狀態純邏輯，僅依賴 swift-crypto（`Crypto`、`_CryptoExtras`，3.8.0 起；同一個 package）；必須保持無額外依賴：
  - `ConstantTime` 常數時間字串比較
  - `PKCE` S256 challenge 產生／驗證（`verify` 不檢查 verifier 格式；`isValidVerifier` 另行檢查 RFC 7636 §4.1）
  - `BearerTokenAuth` gRPC bearer token 授權決策（跨 Context 同一份契約，行為不可單方面改動）
  - `GRPCAuthConfig` gRPC 驗證模式解析（fail-closed）
  - `AccessTokenSigner` / `AccessTokenClaims` 簽發 RFC 9068 `at+jwt`（RS256，header `alg/typ/kid`）；只用 `_RSA`，不用 jose-swift；金鑰收 RSA 私鑰 JWK（必須有 kid）或 PEM + kid，2048 bit 以上；代理 token（`actors` 非空）的 scope 不可含 `*`。驗證不在這裡（在 Middleware）。`sid` 只給 first-party token 使用（spec §4），發行端不可對 application／delegated token 設定；簽發端不檢查，由 Middleware 驗證
- **AuthKitGRPC** — 依賴 `AuthKit` 與 grpc-swift-2（`GRPCCore`）：
  - `BearerTokenServerInterceptor` 以 `BearerTokenAuth` 做決策的 gRPC server interceptor
  - `BearerTokenMetadata` client 端帶 bearer token 的 metadata
- **AuthKitEventSourcing** — 依賴 `AuthKit` 與 swift-ddd-kit（`https://github.com/gradyzhuo/swift-ddd-kit.git`，1.4.0 起；產品名 `DDDKit`）：
  - `SingleUseCode` 可單次兌換、綁定 PKCE 的 aggregate protocol（`markDelete()` 必須 append deleted event）
  - `SingleUseCodeRedeemer` 以 expected-version 寫入保證只兌換一次；只有版本衝突（`DDDError` 的 `.commitConflict`／`.streamPurged`）會轉成 `.alreadyRedeemed`，其他寫入錯誤原樣丟出

## 測試

使用 Swift Testing（`@Test`、`@Suite`、`#expect`），不用 XCTest：

```bash
swift test --no-parallel --disable-xctest --enable-swift-testing
```

`AuthKitEventSourcingTests` 需要本機 KurrentDB（localhost:2113、insecure）；測試讀寫 aggregate 自己的 stream，不需部署 projection。
`AuthKitTests/Fixtures` 的 RSA 金鑰只供測試。
測試用 aggregate `TestCode` 的事件由 swift-ddd-kit 的 `DomainEventGeneratorPlugin`／`ModelGeneratorPlugin` 從 `Tests/AuthKitEventSourcingTests/*.yaml` 產生，不要手改產生的程式碼。
