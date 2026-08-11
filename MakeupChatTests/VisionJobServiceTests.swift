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
        } catch let failure as VisionRequestFailure {
            XCTAssertEqual(failure.visionError, .resultInvalid)
            XCTAssertEqual(failure.stage, .submittingJob)
            XCTAssertEqual(failure.httpStatus, 202)
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
        } catch let failure as VisionRequestFailure {
            XCTAssertEqual(failure.visionError, .resultInvalid)
            XCTAssertEqual(failure.stage, .submittingJob)
            XCTAssertEqual(failure.httpStatus, 200)
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

    func testVisualProfileJobTypeMapsToFaceAnalysisCapability() throws {
        let ticket = try JSONDecoder().decode(
            VisionJobTicketDTO.self,
            from: Data(#"{"job_id":"job-face","job_type":"visual_profile","status":"queued"}"#.utf8)
        )

        XCTAssertEqual(ticket.capability, .faceAnalysis)
    }

    func testItemRecognitionDecodesFrozenColorShapeForAllDemoCategories() throws {
        let result = try JSONDecoder().decode(
            ItemRecognitionResultDTO.self,
            from: Data(#"""
            {
                "recognition_level":"L2",
                "items":[
                    {"item_index":0,"category":"makeup_brush","category_label_zh":"化妆刷","category_confidence":"high","bbox_0_999":[0,0,999,999],"brand_text":null,"product_name_text":"Brush","shade_text":null,"visible_texts":[],"colors":{"applicable":false,"primary":null,"secondary":[],"note":"not applicable","source":null},"needs_confirmation":true,"knowledge_keys":[]},
                    {"item_index":1,"category":"eyeliner","category_label_zh":"眼线","category_confidence":"high","bbox_0_999":[0,0,999,999],"brand_text":"Brand","product_name_text":"Liner","shade_text":"Black","visible_texts":[],"colors":{"applicable":true,"primary":{"family":"black","name_zh":"黑色","hex_estimate":"#111111","confidence_level":"high"},"secondary":[],"note":"","source":"model"},"needs_confirmation":true,"knowledge_keys":[]},
                    {"item_index":2,"category":"eyeshadow_palette","category_label_zh":"眼影盘","category_confidence":"high","bbox_0_999":[0,0,999,999],"brand_text":"Brand","product_name_text":"Palette","shade_text":"Brown","visible_texts":[],"colors":{"applicable":true,"primary":{"family":"brown","name_zh":"棕色","hex_estimate":"#8A5A4A","confidence_level":"high"},"secondary":[{"family":"beige","name_zh":"米色","hex_estimate":"#C89A86","confidence_level":"medium"}],"note":"","source":"model"},"needs_confirmation":true,"knowledge_keys":[]}
                ],
                "warnings":[],
                "knowledge_keys":[]
            }
            """#.utf8)
        )

        XCTAssertEqual(result.items.map(\.category), ["makeup_brush", "eyeliner", "eyeshadow_palette"])
        XCTAssertEqual(result.items[0].colors, [])
        XCTAssertEqual(result.items[1].colors.map(\.hex), ["#111111"])
        XCTAssertEqual(result.items[2].colors.map(\.hex), ["#8A5A4A", "#C89A86"])
        XCTAssertNil(result.items[0].categoryConfidence)
        XCTAssertEqual(result.items[0].categoryConfidenceLevel, "high")
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

    func testVisionRequestFailurePreservesSafeServerDiagnostics() {
        let metadata = APIResponseMetadata(
            serverRequestID: "req_safe_123",
            location: nil,
            retryAfterSeconds: nil
        )
        let error = APIClientError.httpStatus(
            422,
            "演示图片与任务能力不匹配",
            code: "DEMO_FIXTURE_MISMATCH",
            metadata
        )

        let failure = VisionRequestFailure.capturing(error, stage: .submittingJob)
        let message = failure.localizedDescription

        XCTAssertEqual(failure.visionError, .demoFixtureMismatch)
        XCTAssertTrue(message.contains("阶段：提交分析任务"))
        XCTAssertTrue(message.contains("HTTP 状态：422"))
        XCTAssertTrue(message.contains("错误码：DEMO_FIXTURE_MISMATCH"))
        XCTAssertTrue(message.contains("请求编号：req_safe_123"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("bearer"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("access_token"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("image data"))
    }

    func testNetworkUnavailableHasNoInventedHTTPStatusOrRequestID() {
        let failure = VisionRequestFailure.capturing(
            APIClientError.networkUnavailable,
            stage: .submittingJob
        )
        let message = failure.localizedDescription

        XCTAssertEqual(failure.visionError, .networkUnavailable)
        XCTAssertNil(failure.httpStatus)
        XCTAssertNil(failure.serverRequestID)
        XCTAssertTrue(message.contains("错误码：network_unavailable"))
        XCTAssertFalse(message.contains("HTTP 状态："))
        XCTAssertFalse(message.contains("请求编号："))
    }

    func testResumableJobDeletesStaleMissingTimestampAndTerminalRecords() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let invalidJobs = [
            Self.makePendingJob(status: "polling", updatedAt: now.addingTimeInterval(-11 * 60)),
            Self.makePendingJob(status: "polling", updatedAt: nil),
            Self.makePendingJob(status: "succeeded", updatedAt: now),
            Self.makePendingJob(status: "failed", updatedAt: now),
            Self.makePendingJob(status: "timed_out", updatedAt: now),
            Self.makePendingJob(status: "cancelled", updatedAt: now)
        ]

        for invalidJob in invalidJobs {
            let persistence = InMemoryVisionJobPersistence(job: invalidJob)
            XCTAssertNil(try persistence.resumableJob(
                accountID: invalidJob.accountID,
                capability: invalidJob.capability,
                now: now
            ))
            XCTAssertEqual(persistence.removeCount, 1)
            XCTAssertNil(persistence.job)
        }
    }

    func testRecentInProgressJobRemainsResumableAfterTemporaryNetworkFailure() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        for status in ["submitting", "queued", "running", "polling"] {
            let job = Self.makePendingJob(status: status, updatedAt: now.addingTimeInterval(-9 * 60))
            let persistence = InMemoryVisionJobPersistence(job: job)

            let resumed = try persistence.resumableJob(
                accountID: job.accountID,
                capability: job.capability,
                now: now
            )

            XCTAssertEqual(resumed?.requestID, job.requestID)
            XCTAssertEqual(persistence.removeCount, 0)
        }
    }

    func testStaleAndTerminalRecordsCreateFreshPosts() async throws {
        let now = Date()
        let invalidJobs = [
            Self.makePendingJob(status: "polling", updatedAt: now.addingTimeInterval(-11 * 60)),
            Self.makePendingJob(status: "failed", updatedAt: now),
            Self.makePendingJob(status: "timed_out", updatedAt: now),
            Self.makePendingJob(status: "cancelled", updatedAt: now)
        ]

        for invalidJob in invalidJobs {
            VisionURLProtocolStub.requests = []
            let persistence = InMemoryVisionJobPersistence(job: invalidJob)
            VisionURLProtocolStub.handler = { request in
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: request.httpMethod == "POST" ? 202 : 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                if request.httpMethod == "POST" {
                    return (response, Data(#"{"request_id":"server-new","data":{"job_id":"new-job","job_type":"face_analysis","status":"queued"}}"#.utf8))
                }
                return (response, Self.successfulProfileJobData(jobID: "new-job"))
            }

            _ = try await makeVisualProfileProvider(persistence: persistence).analyzePortrait(
                try makePortraitInput(userID: invalidJob.accountID)
            )

            let posts = VisionURLProtocolStub.requests.filter { $0.httpMethod == "POST" }
            XCTAssertEqual(posts.count, 1, "status=\(invalidJob.status)")
            XCTAssertNotEqual(
                Self.multipartValue(named: "request_id", request: try XCTUnwrap(posts.first)),
                invalidJob.requestID
            )
            XCTAssertNil(persistence.job)
        }
    }

    func testFaceAnalysisPendingJobCleanupPolicyKeepsOnlyNetworkFailure() {
        let errorsThatMustClear: [VisionAPIError] = [
            .jobNotFound, .providerUnavailable, .cancelled, .jobTimedOut,
            .resultInvalid, .invalidImage, .unauthorized,
            .demoFixtureNotRecognized, .demoFixtureMismatch, .demoCacheNotReady,
            .payloadTooLarge, .unsupportedMediaType
        ]
        for error in errorsThatMustClear {
            XCTAssertTrue(UnifiedVisualProfileProvider.shouldClearPendingJob(after: error))
        }
        XCTAssertFalse(UnifiedVisualProfileProvider.shouldClearPendingJob(after: .networkUnavailable))
    }

    func testPolling404ClearsRecordAndNextScanCreatesNewJob() async throws {
        let originalJob = Self.makePendingJob(status: "polling", updatedAt: Date())
        let persistence = InMemoryVisionJobPersistence(job: originalJob)
        let input = try makePortraitInput(userID: originalJob.accountID)

        VisionURLProtocolStub.handler = { request in
            let response: HTTPURLResponse
            if request.url?.path == "/v1/vision/jobs/old-job" {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/problem+json"]
                )!
                return (response, Data(#"{"title":"Not Found","status":404,"code":"JOB_NOT_FOUND","request_id":"server-old"}"#.utf8))
            }
            throw URLError(.badURL)
        }

        do {
            _ = try await makeVisualProfileProvider(persistence: persistence).analyzePortrait(input)
            XCTFail("A missing persisted job must fail the current attempt.")
        } catch let failure as VisionRequestFailure {
            XCTAssertEqual(failure.visionError, .jobNotFound)
        }
        XCTAssertNil(persistence.job)
        XCTAssertEqual(persistence.removeCount, 1)

        VisionURLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: request.httpMethod == "POST" ? 202 : 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            if request.httpMethod == "POST" {
                return (response, Data(#"{"request_id":"server-new","data":{"job_id":"new-job","job_type":"face_analysis","status":"queued"}}"#.utf8))
            }
            return (response, Self.successfulProfileJobData(jobID: "new-job"))
        }

        _ = try await makeVisualProfileProvider(persistence: persistence).analyzePortrait(input)
        let requests = VisionURLProtocolStub.requests
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" }.count, 1)
        let post = try XCTUnwrap(requests.first { $0.httpMethod == "POST" })
        XCTAssertNotEqual(Self.multipartValue(named: "request_id", request: post), originalJob.requestID)
        XCTAssertNil(persistence.job)
    }

    func testRecentJobIsRetainedWhenPollingHasTemporaryNetworkFailure() async throws {
        let job = Self.makePendingJob(status: "polling", updatedAt: Date())
        let persistence = InMemoryVisionJobPersistence(job: job)
        VisionURLProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await makeVisualProfileProvider(persistence: persistence).analyzePortrait(
                try makePortraitInput(userID: job.accountID)
            )
            XCTFail("Network failure must be surfaced.")
        } catch let failure as VisionRequestFailure {
            XCTAssertEqual(failure.visionError, .networkUnavailable)
        }

        XCTAssertEqual(persistence.job?.jobID, "old-job")
        XCTAssertEqual(persistence.removeCount, 0)
        XCTAssertEqual(VisionURLProtocolStub.requests.filter { $0.httpMethod == "POST" }.count, 0)
    }

    @MainActor
    func testQuickStartIgnoresConcurrentImageCallbacksAndAllowsLaterRetry() async throws {
        let spy = FirstTimeFaceScanSpy(delay: .milliseconds(80))
        let viewModel = FirstTimeUseViewModel(
            session: AppSession(),
            completeFaceScan: spy.complete
        )
        let input = try makeVisionImageInput()

        let first = Task { await viewModel.handleSelectedInput(input) }
        while !viewModel.isProcessing { await Task.yield() }
        await viewModel.handleSelectedInput(input)
        await first.value

        XCTAssertEqual(spy.callCount, 1)
        XCTAssertFalse(viewModel.isProcessing)

        await viewModel.handleSelectedInput(input)
        XCTAssertEqual(spy.callCount, 2)
        XCTAssertFalse(viewModel.isProcessing)
    }

    @MainActor
    func testQuickStartRestoresProcessingStateAfterFailure() async throws {
        let spy = FirstTimeFaceScanSpy(failuresRemaining: 1)
        let viewModel = FirstTimeUseViewModel(
            session: AppSession(),
            completeFaceScan: spy.complete
        )
        let input = try makeVisionImageInput()

        await viewModel.handleSelectedInput(input)
        XCTAssertEqual(spy.callCount, 1)
        XCTAssertFalse(viewModel.isProcessing)

        await viewModel.handleSelectedInput(input)
        XCTAssertEqual(spy.callCount, 2)
        XCTAssertFalse(viewModel.isProcessing)
    }

    @MainActor
    func testProfileSetupCancellationReturnsToIdleWithoutPopup() async throws {
        let viewModel = UserProfileSetupViewModel(
            analysisService: CancellingFaceAnalysisService()
        )

        let succeeded = await viewModel.analyze(
            try makeVisionImageInput(),
            session: AppSession()
        )

        XCTAssertFalse(succeeded)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNil(viewModel.errorMessage)
        guard case .idle = viewModel.analysisState else {
            return XCTFail("Cancellation must restore the idle analysis state.")
        }
    }

    @MainActor
    func testQuickStartCancellationRestoresStateWithoutPopup() async throws {
        let viewModel = FirstTimeUseViewModel(
            session: AppSession(),
            completeFaceScan: { _ in throw CancellationError() }
        )

        await viewModel.handleSelectedInput(try makeVisionImageInput())

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.processingStage, .none)
        XCTAssertEqual(viewModel.profileAnalysisProgress, 0)
        XCTAssertNil(viewModel.recognitionErrorMessage)
    }

    func testExplicitCancellationClassifierCoversRawAndWrappedCancellation() {
        XCTAssertTrue(isExplicitVisionCancellation(CancellationError()))
        XCTAssertTrue(isExplicitVisionCancellation(URLError(.cancelled)))
        XCTAssertTrue(isExplicitVisionCancellation(VisionAPIError.cancelled))
        XCTAssertTrue(isExplicitVisionCancellation(VisionRequestFailure(
            visionError: .cancelled,
            stage: .pollingJob
        )))
        XCTAssertFalse(isExplicitVisionCancellation(VisionAPIError.networkUnavailable))
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

    func testLiveItemRecognitionContractsWhenExplicitlyEnabled() async throws {
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
        let client = await anonymousClient.authenticated(with: account.accessToken)
        let fixtures = [
            ("demo_tool_brush_set_001", "makeup_brush"),
            ("demo_cosmetic_eyeliner_001", "eyeliner"),
            ("demo_cosmetic_eyeshadow_palette_001", "eyeshadow_palette")
        ]

        for (resource, expectedCategory) in fixtures {
            let fixtureURL = try XCTUnwrap(Bundle.main.url(
                forResource: resource,
                withExtension: "jpg",
                subdirectory: "DemoFixtures"
            ))
            let input = try VisionImageInput(
                photoData: Data(contentsOf: fixtureURL, options: [.mappedIfSafe]),
                contentType: "image/jpeg"
            )
            let response = try await VisionJobService(client: client).create(
                input: input,
                capability: .itemRecognition,
                options: .itemRecognition(.init()),
                requestID: "req_live_item_\(UUID().uuidString.lowercased())",
                idempotencyKey: "idem_live_item_\(UUID().uuidString.lowercased())"
            )
            XCTAssertEqual(response.value.capability, .itemRecognition)

            let result: ItemRecognitionResultDTO = try await JobPoller().poll(
                jobID: response.value.jobId,
                fetch: { jobID in
                    try await AIJobRepository(client: client).job(id: jobID)
                }
            )
            XCTAssertEqual(result.items.first?.category, expectedCategory)
        }
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

    private func makeVisualProfileProvider(
        persistence: InMemoryVisionJobPersistence
    ) -> UnifiedVisualProfileProvider {
        UnifiedVisualProfileProvider(
            client: makeClient(),
            poller: JobPoller(maximumWait: 2, defaultPollMilliseconds: 1),
            persistence: persistence
        )
    }

    private func makePortraitInput(userID: String) throws -> PortraitInput {
        let input = try makeVisionImageInput()
        return PortraitInput(
            image: input.image,
            originalData: input.originalData,
            contentType: input.contentType,
            userID: userID
        )
    }

    private func makeVisionImageInput() throws -> VisionImageInput {
        let data = try XCTUnwrap(UIImage(systemName: "person.crop.circle")?.jpegData(compressionQuality: 1))
        return try VisionImageInput(photoData: data, contentType: "image/jpeg")
    }

    private static func makePendingJob(status: String, updatedAt: Date?) -> VisionPendingJob {
        VisionPendingJob(
            accountID: "user-pending",
            capability: .faceAnalysis,
            requestID: "old-request",
            idempotencyKey: "old-idempotency",
            jobID: status == "submitting" ? nil : "old-job",
            status: status,
            serverRequestID: "server-old",
            location: nil,
            retryAfterSeconds: nil,
            updatedAt: updatedAt
        )
    }

    private static func successfulProfileJobData(jobID: String) -> Data {
        Data(#"{"request_id":"server-success","data":{"job_id":"\#(jobID)","request_id":"client-success","status":"succeeded","progress":null,"result":{"profile_snapshot":{"face":{},"eyes":{},"brows":{},"skin":{},"provenance":[]},"narrative":null,"narrative_status":null,"warnings":[]},"error":null}}"#.utf8)
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

private final class InMemoryVisionJobPersistence: VisionJobPersisting {
    var job: VisionPendingJob?
    private(set) var removeCount = 0

    init(job: VisionPendingJob?) {
        self.job = job
    }

    func pendingJob(accountID: String, capability: VisionCapability) throws -> VisionPendingJob? {
        guard job?.accountID == accountID, job?.capability == capability else { return nil }
        return job
    }

    func savePendingJob(_ job: VisionPendingJob) throws {
        self.job = job
    }

    func removePendingJob(accountID: String, capability: VisionCapability) throws {
        removeCount += 1
        job = nil
    }
}

private struct CancellingFaceAnalysisService: FaceAnalysisServicing {
    func analyze(input: VisionImageInput, userId: String) async throws -> FaceAnalysisResult {
        _ = input
        _ = userId
        throw CancellationError()
    }
}

@MainActor
private final class FirstTimeFaceScanSpy {
    private(set) var callCount = 0
    private var failuresRemaining: Int
    private let delay: Duration

    init(failuresRemaining: Int = 0, delay: Duration = .zero) {
        self.failuresRemaining = failuresRemaining
        self.delay = delay
    }

    func complete(_ input: VisionImageInput) async throws -> [OnboardingStep] {
        _ = input
        callCount += 1
        if delay > .zero { try await Task.sleep(for: delay) }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw VisionAPIError.providerUnavailable
        }
        return []
    }
}
