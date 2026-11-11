import DDDKit

final class TestCodeRepository: EventSourcingRepository {
    typealias StorageCoordinator = ESDBStorageCoordinator<TestCode>
    typealias AggregateRootType = TestCode

    let coordinator: StorageCoordinator

    init(coordinator: StorageCoordinator) {
        self.coordinator = coordinator
    }
}
