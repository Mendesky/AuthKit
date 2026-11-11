// Transplanted from AccountContext/Sources/AccountContextServer/BearerTokenServerInterceptor.swift
import AuthKit
import GRPCCore

/// gRPC server interceptor enforcing a shared bearer token.
///
/// The caller must send `authorization: Bearer <token>` (or the bare token) in metadata,
/// matching the server's configured token; otherwise the call fails with `UNAUTHENTICATED`.
/// The pure decision is delegated to `BearerTokenAuth` (unit-testable); this type only reads
/// grpc metadata and maps the decision to an error.
///
/// Transport is plaintext: the token can be sniffed on the same network segment, so this
/// is only suitable for trusted internal networks; add TLS for untrusted ones.
public struct BearerTokenServerInterceptor: ServerInterceptor {
    let expectedToken: String

    public init(expectedToken: String) {
        self.expectedToken = expectedToken
    }

    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next: @Sendable (
            _ request: StreamingServerRequest<Input>,
            _ context: ServerContext
        ) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        let authorizationValues = Array(request.metadata[stringValues: "authorization"])
        switch BearerTokenAuth.decide(authorizationValues: authorizationValues, expectedToken: expectedToken) {
        case .authorized:
            return try await next(request, context)
        case .missing:
            throw RPCError(code: .unauthenticated, message: "missing authorization metadata")
        case .invalid:
            throw RPCError(code: .unauthenticated, message: "invalid token")
        }
    }
}
