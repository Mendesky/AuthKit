# AuthKit

Mendesky 各 Context 共用的授權邏輯：PKCE、常數時間比對、gRPC bearer token 驗證、單次兌換流程、access token 簽發（at+jwt）。

只放無狀態的邏輯，不放事件定義與資料模型。

設計依據：`IdentityContext/docs/superpowers/specs/2026-11-11-oidc-provider-design.md`（D18）。
Access token 簽發依據：`claude-connector` 的 `specs/2026-11-14-unified-access-token-design.html`（§4、§5「共用的簽發程式」）。
