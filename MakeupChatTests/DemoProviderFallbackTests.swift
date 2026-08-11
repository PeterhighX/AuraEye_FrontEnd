import UIKit
import XCTest
@testable import MakeupChat

final class DemoProviderFallbackTests: XCTestCase {
    func testDemoBusinessErrorDoesNotTriggerSecondEndpoint() async throws {
        VisionURLProtocolStub.requests = []
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 422,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/problem+json"]
            )!
            return (
                response,
                Data(#"{"type":"about:blank","title":"Fixture missing","status":422,"code":"DEMO_FIXTURE_NOT_RECOGNIZED"}"#.utf8)
            )
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VisionURLProtocolStub.self]
        let client = APIClient(
            configuration: .init(
                baseURL: URL(string: "https://example.test/v1")!,
                accessToken: "token",
                timeout: 5
            ),
            session: URLSession(configuration: configuration)
        )
        let input = VisionImageInput(image: try XCTUnwrap(UIImage(systemName: "photo")))

        do {
            _ = try await VisionJobService(client: client).create(
                input: input,
                capability: .faceAnalysis,
                requestID: "request-1",
                idempotencyKey: "request-1"
            )
            XCTFail("Expected a frozen demo business error")
        } catch let failure as VisionRequestFailure {
            XCTAssertEqual(failure.visionError, .demoFixtureNotRecognized)
            XCTAssertEqual(failure.stage, .submittingJob)
            XCTAssertEqual(failure.httpStatus, 422)
            XCTAssertEqual(failure.serverCode, "DEMO_FIXTURE_NOT_RECOGNIZED")
        }

        XCTAssertEqual(VisionURLProtocolStub.requests.map(\.url?.path), ["/v1/vision/jobs"])
    }
}
