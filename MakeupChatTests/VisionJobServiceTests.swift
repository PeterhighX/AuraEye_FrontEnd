import UIKit
import XCTest
@testable import MakeupChat

final class VisionURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            var handledRequest = request
            if handledRequest.httpBody == nil, let stream = request.httpBodyStream {
                handledRequest.httpBody = Self.data(from: stream)
            }
            Self.requests.append(handledRequest)
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(handledRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func data(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 16 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class VisionJobServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        VisionURLProtocolStub.requests = []
        VisionURLProtocolStub.handler = nil
    }

    func testEveryCapabilityUsesSameMultipartEndpointAndOriginalBytes() async throws {
        let original = try XCTUnwrap(UIImage(systemName: "circle.fill")?.jpegData(compressionQuality: 1))
        let input = try VisionImageInput(photoData: original, contentType: "image/jpeg")
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 202,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let capability = Self.multipartValue(named: "capability", request: request) ?? ""
            return (
                response,
                Data(#"{"request_id":"server-req","data":{"contract_version":"1.2","job_id":"job-1","job_type":"\#(capability)","status":"queued"}}"#.utf8)
            )
        }
        let service = VisionJobService(client: makeClient())

        _ = try await service.create(
            input: input,
            capability: .faceAnalysis,
            options: .faceAnalysis(.init()),
            requestID: "request-face",
            idempotencyKey: "request-face"
        )
        _ = try await service.create(
            input: input,
            capability: .itemRecognition,
            options: .itemRecognition(.init()),
            requestID: "request-item",
            idempotencyKey: "request-item"
        )
        _ = try await service.create(
            input: input,
            capability: .makeupRender,
            options: .makeupRender(.init()),
            requestID: "request-makeup",
            idempotencyKey: "request-makeup"
        )

        XCTAssertEqual(VisionURLProtocolStub.requests.count, 3)
        for request in VisionURLProtocolStub.requests {
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/vision/jobs")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), Self.multipartValue(named: "request_id", request: request))
            XCTAssertTrue(try XCTUnwrap(request.httpBody).range(of: original) != nil)
        }
        XCTAssertEqual(
            Self.multipartValue(named: "options", request: VisionURLProtocolStub.requests[0]),
            #"{"consent_version":"visual-analysis-test-v1"}"#
        )
        XCTAssertEqual(
            Self.multipartValue(named: "options", request: VisionURLProtocolStub.requests[1]),
            #"{"recognition_scope":{"allowed_categories":["makeup_brush","eyeliner","eyeshadow_palette"],"max_items":3}}"#
        )
        XCTAssertEqual(
            Self.multipartValue(named: "options", request: VisionURLProtocolStub.requests[2]),
            #"{"recipe_id":"perfect-live-1785130914911"}"#
        )
    }

    func testItemRecognitionMaxItemsIsClampedToBackendRange() throws {
        let options = VisionJobOptions.itemRecognition(.init(maxItems: 4))
        XCTAssertEqual(
            try options.jsonString(),
            #"{"recognition_scope":{"allowed_categories":["makeup_brush","eyeliner","eyeshadow_palette"],"max_items":3}}"#
        )
    }

    func testSuccessfulVisionJobCreationRejectsDirectDTO() async throws {
        let original = try XCTUnwrap(UIImage(systemName: "circle.fill")?.jpegData(compressionQuality: 1))
        let input = try VisionImageInput(photoData: original, contentType: "image/jpeg")
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 202,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let capability = Self.multipartValue(named: "capability", request: request) ?? ""
            return (response, Data(#"{"job_id":"job-1","job_type":"\#(capability)","status":"queued"}"#.utf8))
        }

        do {
            _ = try await VisionJobService(client: makeClient()).create(
                input: input,
                capability: .faceAnalysis,
                requestID: "request-face",
                idempotencyKey: "request-face"
            )
            XCTFail("Direct DTO success responses must be rejected.")
        } catch let error as VisionAPIError {
            XCTAssertEqual(error, .resultInvalid)
        }
    }

    func testVisionJobCreationRequiresHTTP202() async throws {
        let original = try XCTUnwrap(UIImage(systemName: "circle.fill")?.jpegData(compressionQuality: 1))
        let input = try VisionImageInput(photoData: original, contentType: "image/jpeg")
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(#"{"request_id":"server-req","data":{"job_id":"job-1","job_type":"face_analysis","status":"queued"}}"#.utf8)
            )
        }

        do {
            _ = try await VisionJobService(client: makeClient()).create(
                input: input,
                capability: .faceAnalysis,
                requestID: "request-face",
                idempotencyKey: "request-face"
            )
            XCTFail("Vision job creation must accept only HTTP 202.")
        } catch let error as VisionAPIError {
            XCTAssertEqual(error, .resultInvalid)
        }
    }

    func testJobPollingRequiresEnvelope() async throws {
        let repository = AIJobRepository(client: makeClient())
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"job_id":"job-1","status":"succeeded","result":{"items":[],"warnings":[],"knowledge_keys":[],"recognition_level":"low"}}"#.utf8))
        }

        do {
            let _: APIResponse<AIJobDTO<ItemRecognitionResultDTO>> = try await repository.job(id: "job-1")
            XCTFail("Direct DTO poll responses must be rejected.")
        } catch let error as APIClientError {
            XCTAssertEqual(error.statusCode, 200)
        }
    }

    func testFaceAnalysisResultDecodesFrozenBackendFieldNames() async throws {
        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                Data(#"{"request_id":"server-req","data":{"job_id":"job-face","request_id":"client-req","job_type":"face_analysis","status":"succeeded","progress":null,"result":{"profile_snapshot":{"face":{},"eyes":{},"brows":{},"skin":{},"provenance":[]},"narrative":{"overall_contour":"overall","brow_eye_detail":"eyes","style_recommendation":"style"},"narrative_status":"ready","warnings":[]},"error":null}}"#.utf8)
            )
        }

        let response: APIResponse<AIJobDTO<VisualProfileResultDTO>> = try await AIJobRepository(
            client: makeClient()
        ).job(id: "job-face")

        XCTAssertEqual(response.value.result?.narrative?.overall, "overall")
        XCTAssertEqual(response.value.result?.narrative?.eyeDetails, "eyes")
        XCTAssertEqual(response.value.result?.narrative?.styleRecommendation, "style")
    }

    func testResultImageDownloadsThroughAuthenticatedAPIClient() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        VisionURLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/vision/jobs/job-1/result-image")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "image/png")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            )!
            return (response, png)
        }

        let response = try await VisionResultImageService(client: makeClient()).downloadPNG(jobID: "job-1")
        XCTAssertEqual(response.data, png)
        XCTAssertEqual(response.contentType, "image/png")
    }

    func testLiveFaceAnalysisContractWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AURAEYE_RUN_LIVE_CONTRACT"] == "1" else {
            throw XCTSkip("Live API contract test is opt-in.")
        }
        let password = try XCTUnwrap(environment["AURAEYE_LIVE_PASSWORD"])
        let baseURL = try XCTUnwrap(URL(string: "https://api-dev.peterhigh.xyz/v1"))
        let anonymousClient = APIClient(configuration: APIConfiguration(
            baseURL: baseURL,
            accessToken: nil,
            timeout: 45
        ))
        let account = try await RemoteAuthenticationService(client: anonymousClient).login(
            account: "aurayetest",
            password: password
        )
        XCTAssertEqual(account.features.galleryMode, .fixedDemo)

        let fixtureURL = try XCTUnwrap(Bundle.main.url(
            forResource: "demo_face_portrait_001",
            withExtension: "jpg",
            subdirectory: "DemoFixtures"
        ))
        let input = try VisionImageInput(
            photoData: Data(contentsOf: fixtureURL, options: [.mappedIfSafe]),
            contentType: "image/jpeg"
        )
        let authenticatedClient = await anonymousClient.authenticated(with: account.accessToken)
        let requestID = "req_live_swift_\(UUID().uuidString.lowercased())"
        let response = try await VisionJobService(client: authenticatedClient).create(
            input: input,
            capability: .faceAnalysis,
            options: .faceAnalysis(.init()),
            requestID: requestID,
            idempotencyKey: "idem_live_swift_\(UUID().uuidString.lowercased())"
        )
        XCTAssertEqual(response.value.capability, .faceAnalysis)

        let result: VisualProfileResultDTO = try await JobPoller().poll(
            jobID: response.value.jobId,
            fetch: { jobID in
                try await AIJobRepository(client: authenticatedClient).job(id: jobID)
            }
        )
        XCTAssertNotNil(result.narrative?.overall)
        XCTAssertNotNil(result.narrative?.eyeDetails)
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VisionURLProtocolStub.self]
        return APIClient(
            configuration: APIConfiguration(
                baseURL: URL(string: "https://example.test/v1")!,
                accessToken: "token",
                timeout: 5
            ),
            session: URLSession(configuration: configuration)
        )
    }

    static func multipartValue(named name: String, request: URLRequest) -> String? {
        guard let body = request.httpBody,
              let text = String(data: body, encoding: .isoLatin1),
              let fieldRange = text.range(of: "name=\"\(name)\"\r\n\r\n") else { return nil }
        let valueStart = fieldRange.upperBound
        guard let valueEnd = text[valueStart...].range(of: "\r\n")?.lowerBound else { return nil }
        return String(text[valueStart..<valueEnd])
    }
}
