import Foundation
import DDDKit
import AuthKitEventSourcing

/// 測試用的單次兌換 code aggregate，寫法比照 IdentityContext 的 `AuthCode`。
final class TestCode: TestCodeAggregateProtocol, SingleUseCode {
    var metadata: AggregateRootMetadata = .init()

    let id: String
    let codeChallenge: String
    let expiresAt: Date

    init(id: String, codeChallenge: String, expiresAt: Date) throws {
        self.id = id
        self.codeChallenge = codeChallenge
        self.expiresAt = expiresAt

        let event = TestCodeIssued(testCodeId: id, codeChallenge: codeChallenge, expiresAt: expiresAt)
        try self.apply(event: event)
    }

    required convenience init?(first createdEvent: TestCodeIssued, other events: [any DDDCore.DomainEvent]) throws {
        try self.init(id: createdEvent.testCodeId, codeChallenge: createdEvent.codeChallenge, expiresAt: createdEvent.expiresAt)
        try apply(events: events)
        try clearAllDomainEvents()
    }

    func when(event: TestCodeDeleted) throws {
        metadata.delete()
    }
}

extension TestCodeDeleted {
    /// `DeletedEvent` 要求的 init；產生器用的是 alias（`testCodeId`）。
    init(id: UUID, aggregateRootId: String, occurred: Date) {
        self.init(id: id, testCodeId: aggregateRootId, occurred: occurred)
    }
}
