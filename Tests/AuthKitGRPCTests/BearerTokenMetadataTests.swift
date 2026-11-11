import GRPCCore
import Testing
@testable import AuthKitGRPC

@Suite struct BearerTokenMetadataTests {
    @Test func buildsBearerHeader() {
        #expect(Array(BearerTokenMetadata.authorization(token: "abc")[stringValues: "authorization"]) == ["Bearer abc"])
    }

    @Test func nilTokenYieldsEmptyMetadata() {
        #expect(BearerTokenMetadata.authorization(token: nil).isEmpty)
    }

    @Test func emptyTokenYieldsEmptyMetadata() {
        #expect(BearerTokenMetadata.authorization(token: "").isEmpty)
    }
}
