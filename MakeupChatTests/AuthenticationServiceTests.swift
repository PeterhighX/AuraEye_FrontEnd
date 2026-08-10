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

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VisionURLProtocolStub.self]
        return APIClient(
            configuration: APIConfiguration(
                baseURL: URL(string: "https://example.test/v1")!,
                accessToken: nil,
                timeout: 5
            ),
            session: URLSession(configuration: configuration)
        )
    }
}
