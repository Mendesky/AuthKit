import DDDKit

struct UnrelatedStoreError: Error, Equatable {}

/// 讀取走真正的 store，`save` 則模擬與版本衝突無關的寫入失敗（例如連線中斷）。
struct FailingSaveTestCodeRepository: EventSourcingRepository {
    typealias Store = KurrentStorageCoordinator<TestCode, CustomMetadata>
    typealias AggregateRootType = TestCode

    let store: Store

    init(store: Store) {
        self.store = store
    }

    func save(aggregateRoot: TestCode) async throws {
        throw UnrelatedStoreError()
    }
}
