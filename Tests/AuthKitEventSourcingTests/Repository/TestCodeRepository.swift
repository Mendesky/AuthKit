import DDDKit

struct TestCodeRepository: EventSourcingRepository {
    typealias Store = KurrentStorageCoordinator<TestCode, CustomMetadata>
    typealias AggregateRootType = TestCode

    let store: Store

    init(store: Store) {
        self.store = store
    }
}
