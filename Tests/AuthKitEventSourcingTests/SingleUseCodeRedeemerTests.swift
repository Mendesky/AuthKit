import Foundation
import Testing
import KurrentDB
import DDDKit
import TestUtility
import AuthKit
import AuthKitEventSourcing

@Suite(.serialized)
struct SingleUseCodeRedeemerTests {

    let kdbClient = KurrentDBClient(settings: .localhost())
    let repository: TestCodeRepository
    let redeemer: SingleUseCodeRedeemer<TestCodeRepository>

    init() {
        self.repository = TestCodeRepository(store: .init(client: kdbClient, eventMapper: TestCodeAggregateEventMapper()))
        self.redeemer = SingleUseCodeRedeemer(repository: repository)
    }

    /// 建立並存下一個 `TestCode`，回傳其 id。
    func issue(bundle: TestBundle, verifier: String, expiresIn: TimeInterval = 600) async throws -> String {
        let id = await bundle.generateAggregateRootId(for: TestCode.self)
        let code = try TestCode(id: id, codeChallenge: PKCE.challenge(forVerifier: verifier), expiresAt: Date().addingTimeInterval(expiresIn))
        try await repository.save(aggregateRoot: code)
        return id
    }

    @Test func `併發兌換只有一次成功`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = try await issue(bundle: bundle, verifier: "v")
            let redeemer = self.redeemer

            let results: [Result<String, SingleUseCodeError>] = await withTaskGroup(of: Result<String, SingleUseCodeError>.self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        do {
                            return .success(try await redeemer.redeem(id: id, codeVerifier: "v").id)
                        } catch let error as SingleUseCodeError {
                            return .failure(error)
                        } catch {
                            Issue.record("unexpected error: \(error)")
                            return .failure(.notFound)
                        }
                    }
                }
                return await group.reduce(into: []) { $0.append($1) }
            }

            let successes = results.filter { if case .success = $0 { true } else { false } }.count
            let failures: [SingleUseCodeError] = results.compactMap { if case .failure(let error) = $0 { error } else { nil } }

            #expect(successes == 1)
            #expect(failures.count == 7)
            #expect(failures.allSatisfy { $0 == .alreadyRedeemed || $0 == .notFound })
        }
    }

    @Test func `與版本衝突無關的寫入錯誤原樣丟出且不消耗 code`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = try await issue(bundle: bundle, verifier: "v")
            let failingRedeemer = SingleUseCodeRedeemer(repository: FailingSaveTestCodeRepository(store: repository.store))

            await #expect(throws: UnrelatedStoreError()) {
                _ = try await failingRedeemer.redeem(id: id, codeVerifier: "v")
            }
            let redeemed = try await redeemer.redeem(id: id, codeVerifier: "v")
            #expect(redeemed.id == id)
        }
    }

    @Test func `verifier 錯誤不消耗 code`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = try await issue(bundle: bundle, verifier: "v")

            await #expect(throws: SingleUseCodeError.challengeVerifyFailed) {
                _ = try await redeemer.redeem(id: id, codeVerifier: "wrong")
            }
            let redeemed = try await redeemer.redeem(id: id, codeVerifier: "v")
            #expect(redeemed.id == id)
        }
    }

    @Test func `兌換過的 code 回 notFound`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = try await issue(bundle: bundle, verifier: "v")

            _ = try await redeemer.redeem(id: id, codeVerifier: "v")
            // 兌換成功後 stream 已被 purge
            #expect(try await repository.store.fetchEvents(byId: id)?.latestRevision == nil)
            await #expect(throws: SingleUseCodeError.notFound) {
                _ = try await redeemer.redeem(id: id, codeVerifier: "v")
            }
        }
    }

    @Test func `過期的 code 回 expired 且不消耗`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = try await issue(bundle: bundle, verifier: "v")

            await #expect(throws: SingleUseCodeError.expired) {
                _ = try await redeemer.redeem(id: id, codeVerifier: "v", now: Date().addingTimeInterval(3600))
            }
            // 以實際時間仍可兌換
            let redeemed = try await redeemer.redeem(id: id, codeVerifier: "v")
            #expect(redeemed.id == id)
        }
    }

    @Test func `不存在的 id 回 notFound`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let id = await bundle.generateAggregateRootId(for: TestCode.self)

            await #expect(throws: SingleUseCodeError.notFound) {
                _ = try await redeemer.redeem(id: id, codeVerifier: "v")
            }
        }
    }

    @Test func `短的 verifier 也能兌換`() async throws {
        try await withTestBundle(client: kdbClient) { bundle in
            let verifier = "test-codeVerifier"
            let id = try await issue(bundle: bundle, verifier: verifier)

            let redeemed = try await redeemer.redeem(id: id, codeVerifier: verifier)
            #expect(redeemed.id == id)
            #expect(redeemed.codeChallenge == PKCE.challenge(forVerifier: verifier))
        }
    }
}
