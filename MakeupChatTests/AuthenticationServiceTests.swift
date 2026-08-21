import XCTest
@testable import MakeupChat

final class AuthenticationServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        VisionURLProtocolStub.requests = []
        VisionURLProtocolStub.handler = nil
    }

    func testLoginRequestEncodesUsernamePasswordAndRequestID() throws {
        let request = LoginRequest(
            username: "aurayetest",
            password: "secret",
            requestID: "req_login_test-001"
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(object["username"], "aurayetest")
        XCTAssertEqual(object["password"], "secret")
        XCTAssertEqual(object["request_id"], "req_login_test-001")
        XCTAssertNil(object["account"])
    }

    func testGeneratedLoginRequestIDMatchesBackendContract() {
        let requestID = LoginRequest.makeRequestID()

        XCTAssertGreaterThanOrEqual(requestID.count, 8)
        XCTAssertLessThanOrEqual(requestID.count, 128)
        XCTAssertNotNil(requestID.range(
            of: #"^[A-Za-z0-9._:-]+$"#,
            options: .regularExpression
        ))
    }

    func testLogoutRequestEncodesRequiredRefreshTokenAndRequestID() throws {
        let request = LogoutRequest(
            refreshToken: "refresh-token-value",
            requestID: "req_logout_test-001"
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(object["refresh_token"], "refresh-token-value")
        XCTAssertEqual(object["request_id"], "req_logout_test-001")
    }

    func testMissingAPIBaseURLReturnsConfigurationMissing() {
        XCTAssertThrowsError(try APIConfiguration.loadBaseURL(rawValue: nil)) { error in
            XCTAssertEqual(error as? APIConfigurationError, .configurationMissing)
        }
    }

    func testUnexpandedAPIBaseURLIsRejected() {
        XCTAssertThrowsError(
            try APIConfiguration.loadBaseURL(rawValue: "$(AURAEYE_API_BASE_URL)")
        ) { error in
            XCTAssertEqual(
                error as? APIConfigurationError,
                .configurationInvalid("$(AURAEYE_API_BASE_URL)")
            )
        }
    }

    func testNonHTTPSAPIBaseURLIsRejected() {
        XCTAssertThrowsError(
            try APIConfiguration.loadBaseURL(rawValue: "http://api-dev.peterhigh.xyz/v1")
        ) { error in
            XCTAssertEqual(
                error as? APIConfigurationError,
                .configurationInvalid("http://api-dev.peterhigh.xyz/v1")
            )
        }
    }

    @MainActor
    func testMissingConfigurationDoesNotFallBackToLocalLogin() async {
        APIEnvironment.shared.resetForTesting()
        let service = AuthenticationServiceFactory.makeDefault(
            bundle: Bundle(for: AuthenticationServiceTests.self)
        )

        do {
            _ = try await service.login(account: "aurayetest", password: "AuraAye2026")
            XCTFail("Missing API configuration must stop login.")
        } catch let error as APIConfigurationError {
            XCTAssertEqual(error, .configurationMissing)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemoteLoginDecodesEnvelopeAndUsesBearerForAuthMe() async throws {
        VisionURLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/v1/auth/login":
                let body = try XCTUnwrap(request.httpBody)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(object["username"], "aurayetest")
                XCTAssertEqual(object["password"], "secret")
                XCTAssertNotNil(object["request_id"])
                XCTAssertNil(object["account"])

                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (
                    response,
                    Data("""
                    {
                      "request_id": "req_login_server",
                      "data": {
                        "access_token": "remote-access-token",
                        "refresh_token": "remote-refresh-token",
                        "access_token_expires_at": "2026-08-10T14:00:00Z",
                        "user": {
                          "id": "user-demo-001",
                          "username": "aurayetest",
                          "display_name": "Mrs.Zhang",
                          "account_mode": "demo"
                        },
                        "features": {
                          "gallery_mode": "authorized_library",
                          "use_demo_assets": false,
                          "allow_live_recognition_seed": false
                        }
                      }
                    }
                    """.utf8)
                )
            case "/v1/auth/me":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer remote-access-token")
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (
                    response,
                    Data("""
                    {
                      "request_id": "req_me_server",
                      "data": {
                        "features": {
                          "gallery_mode": "fixed_demo",
                          "use_demo_assets": true,
                          "allow_live_recognition_seed": false
                        }
                      }
                    }
                    """.utf8)
                )
            default:
                throw URLError(.badURL)
            }
        }

        let service = RemoteAuthenticationService(client: makeClient())
        let account = try await service.login(account: "aurayetest", password: "secret")

        XCTAssertEqual(account.accessToken, "remote-access-token")
        XCTAssertEqual(account.username, "aurayetest")
        XCTAssertEqual(account.accountMode, .demo)
        XCTAssertEqual(account.features.galleryMode, .fixedDemo)
        XCTAssertEqual(VisionURLProtocolStub.requests.map(\.url?.path), [
            "/v1/auth/login",
            "/v1/auth/me"
        ])
    }

    func testLoginRequiresHTTP200() async throws {
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(#"{"request_id":"req","data":{"access_token":"token"}}"#.utf8)
            )
        }

        do {
            _ = try await RemoteAuthenticationService(client: makeClient())
                .login(account: "aurayetest", password: "secret")
            XCTFail("Login must accept only HTTP 200.")
        } catch let error as APIClientError {
            XCTAssertEqual(error.statusCode, 201)
        }
    }

    func testRefreshAndLogoutRequireHTTP200() async throws {
        VisionURLProtocolStub.handler = { request in
            let status = request.url?.path == "/v1/auth/refresh" ? 201 : 204
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"request_id":"req","data":{}}"#.utf8))
        }
        let service = RemoteAuthenticationService(client: makeClient())

        do {
            _ = try await service.refresh(refreshToken: "refresh-token")
            XCTFail("Refresh must accept only HTTP 200.")
        } catch let error as APIClientError {
            XCTAssertEqual(error.statusCode, 201)
        }

        do {
            try await service.logout(accessToken: "access-token", refreshToken: "refresh-token")
            XCTFail("Logout must accept only HTTP 200.")
        } catch let error as APIClientError {
            XCTAssertEqual(error.statusCode, 204)
        }
    }

    func testLogoutRequiresRevokedResponseField() async throws {
        VisionURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/logout")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            let body = try XCTUnwrap(request.httpBody)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(object["refresh_token"], "refresh-token")
            XCTAssertNotNil(object["request_id"])
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"request_id":"req","data":{"revoked":true}}"#.utf8))
        }

        try await RemoteAuthenticationService(client: makeClient()).logout(
            accessToken: "access-token",
            refreshToken: "refresh-token"
        )
    }

    func testTransportMapsURLCancellationToCancellationError() async throws {
        let client = makeClient(dataLoader: { _ in throw URLError(.cancelled) })
        do {
            let _: APIResponse<JSONValue> = try await client.sendResponse(
                path: APIEndpoint.healthLive,
                expectedStatusCode: 200
            )
            XCTFail("URLError.cancelled must not become networkUnavailable.")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testTransportPreservesSwiftCancellationError() async throws {
        let client = makeClient(dataLoader: { _ in throw CancellationError() })
        do {
            let _: APIResponse<JSONValue> = try await client.sendResponse(
                path: APIEndpoint.healthLive,
                expectedStatusCode: 200
            )
            XCTFail("CancellationError must pass through unchanged.")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testTransportMapsRealNetworkFailureToNetworkUnavailable() async throws {
        let client = makeClient(dataLoader: { _ in throw URLError(.notConnectedToInternet) })
        do {
            let _: APIResponse<JSONValue> = try await client.sendResponse(
                path: APIEndpoint.healthLive,
                expectedStatusCode: 200
            )
            XCTFail("A real connection failure must become networkUnavailable.")
        } catch let error as APIClientError {
            guard case .networkUnavailable = error else {
                return XCTFail("Unexpected APIClientError: \(error)")
            }
            XCTAssertNil(error.statusCode)
            XCTAssertNil(error.diagnosticRequestID)
        }
    }

    func testTransportRefactorPreservesHTTPStatusAndBackendCode() async throws {
        for (status, code) in [(401, "UNAUTHORIZED"), (422, "INVALID_OPTIONS"), (404, "JOB_NOT_FOUND")] {
            let client = makeClient(dataLoader: { request in
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/problem+json"]
                )!
                return (
                    Data(#"{"title":"Request failed","status":\#(status),"code":"\#(code)","request_id":"safe-request"}"#.utf8),
                    response
                )
            })

            do {
                let _: APIResponse<JSONValue> = try await client.sendResponse(
                    path: APIEndpoint.healthLive,
                    expectedStatusCode: 200
                )
                XCTFail("HTTP \(status) must fail.")
            } catch let error as APIClientError {
                XCTAssertEqual(error.statusCode, status)
                XCTAssertEqual(error.problemCode, code)
                XCTAssertEqual(error.diagnosticRequestID, "safe-request")
            }
        }
    }

    @MainActor
    func testAuthenticatedRequestRefreshesOnceAfterUnauthorizedAndRetries() async throws {
        SessionManager.shared.establish(account: AuthenticatedAccount(
            userId: "user-1",
            username: "aurayetest",
            displayName: "Demo",
            accessToken: "expired-access-token",
            refreshToken: "refresh-token",
            expiresAt: nil,
            accountMode: .demo,
            features: .demo
        ))
        defer { SessionManager.shared.clear() }

        VisionURLProtocolStub.handler = { request in
            let isRefresh = request.url?.path == "/v1/auth/refresh"
            let isRetriedRequest = request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-access-token"
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: isRefresh || isRetriedRequest ? 200 : 401,
                httpVersion: nil,
                headerFields: ["Content-Type": isRefresh || isRetriedRequest
                    ? "application/json" : "application/problem+json"]
            )!
            switch request.url?.path {
            case "/v1/auth/refresh":
                let body = try XCTUnwrap(request.httpBody)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(object["refresh_token"], "refresh-token")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                return (response, Data("""
                {"request_id":"refresh","data":{"access_token":"fresh-access-token","refresh_token":"next-refresh-token","access_token_expires_at":"2026-08-11T14:00:00Z","user":{"id":"user-1","username":"aurayetest","display_name":"Demo","account_mode":"demo"},"features":{"gallery_mode":"fixed_demo","use_demo_assets":true,"allow_live_recognition_seed":false}}}
                """.utf8))
            case "/v1/vision/jobs/job-1":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-access-token" {
                    return (response, Data(#"{"request_id":"job","data":{"job_id":"job-1","status":"succeeded","result":{}}}"#.utf8))
                }
                return (response, Data(#"{"title":"Unauthorized","status":401,"code":"INVALID_SESSION","retryable":false,"request_id":"expired"}"#.utf8))
            default:
                throw URLError(.badURL)
            }
        }

        let anonymousClient = makeClient()
        let authenticatedClient = await anonymousClient.authenticated(with: "expired-access-token")
        let response: APIResponse<AIJobDTO<JSONValue>> = try await authenticatedClient.sendResponse(
            path: APIEndpoint.visionJob("job-1"),
            expectedStatusCode: 200
        )

        XCTAssertEqual(response.value.jobId, "job-1")
        XCTAssertEqual(SessionManager.shared.context?.accessToken, "fresh-access-token")
        XCTAssertEqual(SessionManager.shared.context?.refreshToken, "next-refresh-token")
        XCTAssertEqual(VisionURLProtocolStub.requests.map(\.url?.path), [
            "/v1/vision/jobs/job-1",
            "/v1/auth/refresh",
            "/v1/vision/jobs/job-1"
        ])
    }

    @MainActor
    func testAuthenticationAndVisionUseSameConfiguredBaseURL() async throws {
        let configuration = APIConfiguration(
            baseURL: URL(string: "https://example.test/v1")!,
            accessToken: nil,
            timeout: 5
        )
        APIEnvironment.shared.install(configuration)
        SessionManager.shared.establish(account: AuthenticatedAccount(
            userId: "user-1",
            username: "aurayetest",
            displayName: "Demo",
            accessToken: "access-token",
            expiresAt: nil,
            accountMode: .demo,
            features: .demo
        ))
        defer {
            SessionManager.shared.clear()
            APIEnvironment.shared.resetForTesting()
        }

        let visionClient = try VisionClientFactory.authenticatedClient()
        let visionBaseURL = await visionClient.configuredBaseURL()
        XCTAssertEqual(visionBaseURL, configuration.baseURL)
    }

    private func makeClient(
        dataLoader: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil
    ) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VisionURLProtocolStub.self]
        return APIClient(
            configuration: APIConfiguration(
                baseURL: URL(string: "https://example.test/v1")!,
                accessToken: nil,
                timeout: 5
            ),
            session: URLSession(configuration: configuration),
            dataLoader: dataLoader
        )
    }
}

final class ChatContractTests: XCTestCase {
    override func setUp() {
        super.setUp()
        VisionURLProtocolStub.requests = []
        VisionURLProtocolStub.handler = nil
    }

    func testChatRequestEncodesExactlyFrozenFields() throws {
        let request = ChatSendRequest(
            requestId: "req_chat_01JTEST",
            conversationId: "conversation_01JTEST",
            message: "请推荐通勤妆容"
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]
        )

        XCTAssertEqual(Set(object.keys), ["request_id", "conversation_id", "message"])
        XCTAssertNil(object["user_id"])
        XCTAssertNil(object["display_name"])
    }

    func testRemoteChatUsesBearerAndRequires201Envelope() async throws {
        VisionURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/chat/messages")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer chat-access-token")
            let body = try XCTUnwrap(request.httpBody)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(Set(object.keys), ["request_id", "conversation_id", "message"])
            XCTAssertEqual(object["request_id"], "req_chat_01JTEST")
            XCTAssertEqual(object["conversation_id"], "conversation_01JTEST")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "X-Request-Id": "req_http_chat_01"]
            )!
            return (response, Data("""
            {"request_id":"req_http_chat_01","data":{"client_request_id":"req_chat_01JTEST","conversation_id":"conversation_01JTEST","message_id":"resp_01","message":"已为你整理通勤妆容建议。","avatar_asset":"AvatarAI2","status":"completed"}}
            """.utf8))
        }

        let reply = try await RemoteAIAgentService(client: makeAuthenticatedClient()).send(
            ChatSendRequest(requestId: "req_chat_01JTEST", conversationId: "conversation_01JTEST", message: "请推荐通勤妆容")
        )
        XCTAssertEqual(reply.clientRequestId, "req_chat_01JTEST")
        XCTAssertEqual(reply.conversationId, "conversation_01JTEST")
        XCTAssertEqual(reply.messageId, "resp_01")
        XCTAssertEqual(reply.serverRequestId, "req_http_chat_01")
    }

    func testRemoteChatRejectsMismatchedClientRequestID() async throws {
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 201, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("""
            {"request_id":"req_http","data":{"client_request_id":"req_other","conversation_id":"conversation_01JTEST","message_id":"resp_01","message":"回复","avatar_asset":"AvatarAI2","status":"completed"}}
            """.utf8))
        }

        do {
            _ = try await RemoteAIAgentService(client: makeAuthenticatedClient()).send(
                ChatSendRequest(requestId: "req_chat_01JTEST", conversationId: "conversation_01JTEST", message: "测试")
            )
            XCTFail("Mismatched client request ID must be rejected")
        } catch is ChatContractError {
            // Expected.
        }
    }

    @MainActor
    func testAccountScopedStoreKeepsConversationAndMessagesSeparated() async throws {
        let first = SessionContext(userId: "chat-user-a-\(UUID().uuidString)", username: "alpha", displayName: "Alpha", accountMode: .standard, features: .standard, accessToken: "a", refreshToken: nil)
        let second = SessionContext(userId: "chat-user-b-\(UUID().uuidString)", username: "beta", displayName: "Beta", accountMode: .standard, features: .standard, accessToken: "b", refreshToken: nil)
        let firstStore = AccountScopedChatStore(context: first, agentService: ChatReplyStub())
        let secondStore = AccountScopedChatStore(context: second, agentService: ChatReplyStub())

        let firstConversation = try firstStore.load().1
        _ = try secondStore.load()
        try await firstStore.sendNew(text: "第一账号消息")

        XCTAssertNotEqual(firstConversation, try secondStore.load().1)
        XCTAssertEqual(try firstStore.messages().count, 2)
        XCTAssertTrue(try secondStore.messages().isEmpty)
    }

    func testHermesUnavailableIsRetryableButInvalidResponseIsNot() {
        let unavailable = ChatRequestFailure.capture(APIClientError.httpStatus(
            503, "Hermes unavailable", code: "HERMES_UNAVAILABLE",
            APIResponseMetadata(serverRequestID: "req", location: nil, retryAfterSeconds: nil)
        ))
        XCTAssertTrue(unavailable.retryable)
        XCTAssertFalse(ChatRequestFailure.capture(ChatContractError.invalidResponse).retryable)
    }

    private func makeAuthenticatedClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VisionURLProtocolStub.self]
        return APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.test/v1")!, accessToken: "chat-access-token", timeout: 5),
            session: URLSession(configuration: configuration)
        )
    }
}

private struct ChatReplyStub: AIAgentServicing {
    func send(_ request: ChatSendRequest) async throws -> ChatReply {
        ChatReply(clientRequestId: request.requestId, conversationId: request.conversationId, messageId: "resp_\(request.requestId)", message: "远端回复", avatarAsset: "AvatarAI2", status: "completed", serverRequestId: "server_\(request.requestId)")
    }
}
