# CLAUDE.md

## 用途

AuthKit 是供各 Context 微服務共用的 Swift 套件，只放**無狀態的授權邏輯**。不放事件定義與資料模型。
Swift tools 6.0、macOS 15+、`swiftLanguageModes: [.v5]`。

## Targets

- **AuthKit**（目前唯一 target）— 無狀態純邏輯，僅依賴 swift-crypto：
  - `ConstantTime` 常數時間字串比較
  - `PKCE` S256 challenge 產生／驗證（`verify` 不檢查 verifier 格式；`isValidVerifier` 另行檢查 RFC 7636 §4.1）
  - `BearerTokenAuth` gRPC bearer token 授權決策（跨 Context 同一份契約，行為不可單方面改動）
  - `GRPCAuthConfig` gRPC 驗證模式解析（fail-closed）
- 後續會新增 gRPC 與事件溯源 target，各自帶自己的依賴；核心 target 必須保持無額外依賴。

## 測試

使用 Swift Testing（`@Test`、`@Suite`、`#expect`），不用 XCTest：

```bash
swift test --no-parallel --disable-xctest --enable-swift-testing
```
