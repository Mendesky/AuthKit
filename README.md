# AuthKit

Mendesky 各 Context 共用的授權邏輯：PKCE、常數時間比對、gRPC bearer token 驗證、單次兌換流程。

只放無狀態的邏輯，不放事件定義與資料模型。

設計依據：`IdentityContext/docs/superpowers/specs/2026-11-11-oidc-provider-design.md`（D18）。
