import Foundation
import AuthKit
import DDDKit
import KurrentDB

/// 以版本檢查保證一個 `SingleUseCode` 只會被兌換一次。
///
/// `find(byId:)` 帶回 aggregate 的 revision，`save` 以該 revision 做 expected-version 寫入；
/// 併發兌換時只有第一個寫入刪除事件的呼叫者成功，其餘得到 `.alreadyRedeemed`（或在刪除後讀取而得到 `.notFound`）。
/// revision 過舊一律 fail closed（得到 `.alreadyRedeemed`），包括 stream 中有 event mapper 讀不懂的事件、使 `find` 帶回的 revision 落後於實際 revision 的情況。
/// 版本衝突以外的寫入錯誤（例如連線中斷）原樣丟出，此時 code 未被消耗。
public struct SingleUseCodeRedeemer<Repository: EventSourcingRepository> where Repository.AggregateRootType: SingleUseCode {
    let repository: Repository

    public init(repository: Repository) {
        self.repository = repository
    }

    /// 成功時回傳兌換當下的 aggregate（刪除事件已寫入）
    public func redeem(id: Repository.AggregateRootType.ID, codeVerifier: String, now: Date = Date()) async throws -> Repository.AggregateRootType {
        // 前三步只讀不寫：失敗時 code 不被消耗。
        guard let aggregate = try await repository.find(byId: id) else {
            throw SingleUseCodeError.notFound
        }
        guard aggregate.expiresAt > now else {
            throw SingleUseCodeError.expired
        }
        // 不檢查 verifier 格式（既有第一方 client 使用較短的 verifier）。
        guard PKCE.verify(verifier: codeVerifier, challenge: aggregate.codeChallenge) else {
            throw SingleUseCodeError.challengeVerifyFailed
        }

        try aggregate.markDelete()
        do {
            try await repository.save(aggregateRoot: aggregate, external: nil)
        } catch KurrentError.wrongExpectedVersion {
            // 以 find 帶回的 revision 寫入失敗：已被其他呼叫者兌換。
            throw SingleUseCodeError.alreadyRedeemed
        }

        // 不能用 repository.purge(byId:)：它會先 find，而 find 對已標記刪除的 aggregate 回 nil。
        try? await repository.coordinator.purge(byId: id)
        return aggregate
    }
}
