import DDDKit

struct UnrelatedStoreError: Error, Equatable {}

/// 讀取走真正的 store，`save` 則模擬與版本衝突無關的寫入失敗（例如連線中斷）。
final class FailingSaveTestCodeRepository: EventSourcingRepository {
    typealias StorageCoordinator = ESDBStorageCoordinator<TestCode>
    typealias AggregateRootType = TestCode

    let coordinator: StorageCoordinator

    init(coordinator: StorageCoordinator) {
        self.coordinator = coordinator
    }

    func save(aggregateRoot: TestCode, external: [String: String]?) async throws {
        throw UnrelatedStoreError()
    }
}
