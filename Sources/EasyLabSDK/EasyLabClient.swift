// EasyLab typed client SDK for Swift.
//
// One entrypoint, one baseUrl: the easylab gateway. It serves both the
// easylab.v1.* surface (lab/ops/registry) and the agent.v1.* surface
// (sessions/providers/... forwarded to the abc agent backend). External
// frontends never talk to the agent directly.
//
// Usage:
//   let client = EasyLabClient(baseUrl: "https://easylab.example.com", token: "...")
//   let repos = try await client.lab.listRepos(request: .init())
import Connect
import Foundation

/// Interceptor that adds an `Authorization: Bearer <token>` header to every
/// outbound request (both unary and streaming).
final class BearerInterceptor: UnaryInterceptor, StreamInterceptor, Sendable {
    private let token: String

    init(token: String) {
        self.token = token
    }

    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers["Authorization"] = ["Bearer \(self.token)"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }

    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers["Authorization"] = ["Bearer \(self.token)"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }
}

/// The typed easylab gateway client: lab + ops + registry + agent surfaces.
public final class EasyLabClient: Sendable {
    public let lab: Easylab_V1_LabServiceClientInterface
    public let ops: Easylab_V1_OpsServiceClientInterface
    public let registry: Easylab_V1_RegistryServiceClientInterface
    public let agent: Agent_V1_AgentServiceClientInterface

    public init(
        baseUrl: String,
        token: String,
        httpClient: HTTPClientInterface = URLSessionHTTPClient()
    ) {
        let host = baseUrl.hasSuffix("/")
            ? String(baseUrl.dropLast())
            : baseUrl
        let protocolClient = ProtocolClient(
            httpClient: httpClient,
            config: ProtocolClientConfig(
                host: host,
                networkProtocol: .connect,
                codec: ProtoCodec(),
                interceptors: [
                    InterceptorFactory { _ in BearerInterceptor(token: token) },
                ]
            )
        )
        self.lab = Easylab_V1_LabServiceClient(client: protocolClient)
        self.ops = Easylab_V1_OpsServiceClient(client: protocolClient)
        self.registry = Easylab_V1_RegistryServiceClient(client: protocolClient)
        self.agent = Agent_V1_AgentServiceClient(client: protocolClient)
    }
}
