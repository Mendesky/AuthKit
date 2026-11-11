import Testing
@testable import AuthKit

@Suite("GRPCAuthConfig")
struct GRPCAuthConfigTests {
    @Test("resolve modes")
    func resolve() {
        #expect(GRPCAuthConfig.resolve(token: "t", disabledFlag: nil) == .enabled(token: "t"))
        #expect(GRPCAuthConfig.resolve(token: "t", disabledFlag: "1") == .enabled(token: "t"))
        #expect(GRPCAuthConfig.resolve(token: nil, disabledFlag: "1") == .disabled)
        #expect(GRPCAuthConfig.resolve(token: "", disabledFlag: "1") == .disabled)
        #expect(GRPCAuthConfig.resolve(token: "", disabledFlag: nil) == .notConfigured)
        #expect(GRPCAuthConfig.resolve(token: nil, disabledFlag: nil) == .notConfigured)
        #expect(GRPCAuthConfig.resolve(token: nil, disabledFlag: "true") == .notConfigured)
    }
}
