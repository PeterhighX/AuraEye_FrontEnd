import Foundation
import Observation

// Public AuraEye business DTOs. These routes are frozen in docs 14–17 and may
// return 404 until the corresponding backend controllers are deployed.
struct GrowthOverviewDTO: Decodable, Sendable {
    struct Wallet: Decodable, Sendable {
        let availablePoints: Int
        let heldPoints: Int
        let lifetimeEarned: Int
        let lifetimeSpent: Int

        enum CodingKeys: String, CodingKey {
            case availablePoints = "available_points"
            case heldPoints = "held_points"
            case lifetimeEarned = "lifetime_earned"
            case lifetimeSpent = "lifetime_spent"
        }
    }

    struct ExchangeRate: Decodable, Sendable {
        let pointsPerPerfectUnit: Int
        let ruleVersion: Int

        enum CodingKeys: String, CodingKey {
            case pointsPerPerfectUnit = "points_per_perfect_unit"
            case ruleVersion = "rule_version"
        }
    }

    let wallet: Wallet
    let level: Int
    let totalXP: Int
    let levelProgress: Double
    let completedMakeupCount: Int
    let exchangeRate: ExchangeRate
    let tasks: [GrowthTaskDTO]

    enum CodingKeys: String, CodingKey {
        case wallet, level, tasks
        case totalXP = "total_xp"
        case levelProgress = "level_progress"
        case completedMakeupCount = "completed_makeup_count"
        case exchangeRate = "exchange_rate"
    }
}

struct GrowthTaskDTO: Decodable, Identifiable, Sendable {
    let taskID: String
    let kind: String
    let title: String
    let status: String
    let rewardPoints: Int
    let rewardXP: Int
    let progress: Int
    let target: Int
    let expiresAt: String?
    let unavailableReason: String?
    let unavailableMessage: String?

    var id: String { taskID }
    var isRewarded: Bool { status == "rewarded" }

    enum CodingKeys: String, CodingKey {
        case kind, title, status, progress, target
        case taskID = "task_id"
        case rewardPoints = "reward_points"
        case rewardXP = "reward_xp"
        case expiresAt = "expires_at"
        case unavailableReason = "unavailable_reason"
        case unavailableMessage = "unavailable_message"
    }
}

struct UserPortraitDTO: Decodable, Sendable {
    let portraitID: String
    let status: String
    let sourceProfileVersion: Int
    let sourceJobID: String
    let width: Int
    let height: Int
    let hasAlpha: Bool
    let error: BusinessErrorDTO?

    enum CodingKeys: String, CodingKey {
        case status, width, height, error
        case portraitID = "portrait_id"
        case sourceProfileVersion = "source_profile_version"
        case sourceJobID = "source_job_id"
        case hasAlpha = "has_alpha"
    }
}

struct BusinessErrorDTO: Decodable, Sendable {
    let code: String
    let message: String
    let retryable: Bool
}

struct UserVisualProfileDTO: Decodable, Sendable {
    struct Profile: Decodable, Sendable {
        let profileVersion: Int
        let sourceJobID: String
        let resultSource: String
        let observedAt: String
        let snapshot: [String: JSONValue]
        let narrative: VisualProfileNarrativeDTO?
        let narrativeStatus: String?
        let portrait: UserPortraitDTO?

        enum CodingKeys: String, CodingKey {
            case portrait, snapshot, narrative
            case profileVersion = "profile_version"
            case sourceJobID = "source_job_id"
            case resultSource = "result_source"
            case observedAt = "observed_at"
            case narrativeStatus = "narrative_status"
        }
    }

    let profile: Profile?
}

struct KnowledgeTipDTO: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let id: String
        let text: String
        let category: String
        let contentVersion: String

        enum CodingKeys: String, CodingKey {
            case id, text, category
            case contentVersion = "content_version"
        }
    }

    let item: Item?
}

struct WeatherCopyDTO: Decodable, Sendable {
    let text: String
    let weatherStatus: String
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case text
        case weatherStatus = "weather_status"
        case generatedAt = "generated_at"
    }
}

struct MakeupStyleDTO: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let tag: String
    let summary: String
    let swatchHexes: [String]
    let heroAssetKey: String?
    let styleVersion: Int

    enum CodingKeys: String, CodingKey {
        case id, title, tag, summary
        case swatchHexes = "swatch_hexes"
        case heroAssetKey = "hero_asset_key"
        case styleVersion = "style_version"
    }
}

struct MakeupStylesDTO: Decodable, Sendable {
    let items: [MakeupStyleDTO]
}

struct CosmeticDTO: Decodable, Identifiable, Sendable {
    let id: String
    let category: String
    let displayName: String
    let brand: String?
    let shade: String?
    let attributes: [String: JSONValue]?
    let hasImage: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, category, brand, shade, attributes
        case displayName = "display_name"
        case hasImage = "has_image"
        case updatedAt = "updated_at"
    }
}

private struct CosmeticsPageDTO: Decodable {
    let items: [CosmeticDTO]
    let nextCursor: String?
    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

private struct CreateCosmeticRequest: Encodable {
    let requestID: String
    let sourceJobID: String?
    let category: String
    let displayName: String
    let brand: String?
    let shade: String?
    let attributes: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case category, brand, shade, attributes
        case requestID = "request_id"
        case sourceJobID = "source_job_id"
        case displayName = "display_name"
    }
}

private struct UpdateCosmeticRequest: Encodable {
    let displayName: String
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

private struct DeleteCosmeticResponse: Decodable {
    let deleted: Bool
}

struct MakeupHistoryDTO: Decodable, Identifiable, Sendable {
    let sessionID: String
    let planID: String
    let status: String
    let styleTitle: String
    let ordinal: Int?
    let completedAt: String?
    let completionRate: Double

    var id: String { sessionID }

    enum CodingKeys: String, CodingKey {
        case status
        case sessionID = "session_id"
        case planID = "plan_id"
        case styleTitle = "style_title"
        case ordinal
        case completedAt = "completed_at"
        case completionRate = "completion_rate"
    }
}

struct MakeupHistoryPageDTO: Decodable, Sendable {
    let items: [MakeupHistoryDTO]
    let nextCursor: String?
    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct MakeupStatsDTO: Decodable, Sendable {
    struct SpeedComparison: Decodable, Sendable {
        let styleID: String
        let percentFaster: Double
        let comparableSessionCount: Int
        enum CodingKeys: String, CodingKey {
            case styleID = "style_id"
            case percentFaster = "percent_faster"
            case comparableSessionCount = "comparable_session_count"
        }
    }
    let completedCount: Int
    let startedCount: Int
    let completionRate: Double
    let averageActiveDurationMS: Int?
    let speedComparison: SpeedComparison?
    enum CodingKeys: String, CodingKey {
        case completedCount = "completed_count"
        case startedCount = "started_count"
        case completionRate = "completion_rate"
        case averageActiveDurationMS = "average_active_duration_ms"
        case speedComparison = "speed_comparison"
    }
}

private struct MakeupFeedbackRequest: Encodable {
    let requestID: String
    let rating: Int
    let tags: [String]
    let comment: String?
    enum CodingKeys: String, CodingKey {
        case rating, tags, comment
        case requestID = "request_id"
    }
}

private struct MakeupFeedbackResponse: Decodable {
    let rating: Int
}

struct MakeupPlanStepDTO: Decodable, Identifiable, Sendable {
    let id: String
    let order: Int
    let title: String
    let toolName: String?
    let cosmeticIDs: [String]
    let instruction: String
    let tip: String?
    let previewAssetKey: String?

    enum CodingKeys: String, CodingKey {
        case id, order, title, instruction, tip
        case toolName = "tool_name"
        case cosmeticIDs = "cosmetic_ids"
        case previewAssetKey = "preview_asset_key"
    }
}

struct MakeupPlanDTO: Decodable, Sendable {
    struct Render: Decodable, Sendable {
        let status: String
        let jobID: String?
        let error: BusinessErrorDTO?
        enum CodingKeys: String, CodingKey {
            case status, error
            case jobID = "job_id"
        }
    }

    let planID: String
    let status: String
    let planVersion: Int
    let styleID: String
    let title: String
    let summary: String
    let swatchHexes: [String]
    let portrait: UserPortraitDTO?
    let steps: [MakeupPlanStepDTO]
    let render: Render

    enum CodingKeys: String, CodingKey {
        case status, title, summary, portrait, steps, render
        case planID = "plan_id"
        case planVersion = "plan_version"
        case styleID = "style_id"
        case swatchHexes = "swatch_hexes"
    }
}

struct MakeupPlanTicketDTO: Decodable, Sendable {
    let planID: String
    let status: String
    let pollAfterMS: Int
    enum CodingKeys: String, CodingKey {
        case status
        case planID = "plan_id"
        case pollAfterMS = "poll_after_ms"
    }
}

struct MakeupRenderResultDTO: Decodable, Sendable {
    struct OutputAsset: Decodable, Sendable {
        let assetID: String
        let downloadURL: String
        let expiresAt: String
        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case downloadURL = "download_url"
            case expiresAt = "expires_at"
        }
    }
    struct PortraitPreview: Decodable, Sendable {
        let status: String
        let sourcePortraitID: String
        let assetID: String?
        enum CodingKeys: String, CodingKey {
            case status
            case sourcePortraitID = "source_portrait_id"
            case assetID = "asset_id"
        }
    }
    let schemaVersion: String
    let resultSource: String
    let recipeID: String
    let recipeHash: String
    let outputAsset: OutputAsset
    let portraitPreview: PortraitPreview?
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case resultSource = "result_source"
        case recipeID = "recipe_id"
        case recipeHash = "recipe_hash"
        case outputAsset = "output_asset"
        case portraitPreview = "portrait_preview"
    }
}

private struct MakeupRenderJobDTO: Decodable {
    let jobID: String
    let jobType: String
    let status: String
    let result: MakeupRenderResultDTO?
    enum CodingKeys: String, CodingKey {
        case status, result
        case jobID = "job_id"
        case jobType = "job_type"
    }
}

struct MakeupSessionDTO: Decodable, Sendable {
    let sessionID: String
    let status: String
    let planVersion: Int
    let currentStepID: String?
    let currentStep: MakeupPlanStepDTO?
    let completedStepCount: Int
    let totalStepCount: Int
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case status, explanation
        case sessionID = "session_id"
        case planVersion = "plan_version"
        case currentStepID = "current_step_id"
        case currentStep = "current_step"
        case completedStepCount = "completed_step_count"
        case totalStepCount = "total_step_count"
    }
}

struct MakeupCompletionDTO: Decodable, Sendable {
    struct GrowthDelta: Decodable, Sendable {
        let levelBefore: Int
        let levelAfter: Int
        let xpAwarded: Int
        let pointsAwarded: Int
        let taskIDsRewarded: [String]

        enum CodingKeys: String, CodingKey {
            case levelBefore = "level_before"
            case levelAfter = "level_after"
            case xpAwarded = "xp_awarded"
            case pointsAwarded = "points_awarded"
            case taskIDsRewarded = "task_ids_rewarded"
        }
    }

    let ordinal: Int
    let completionRate: Double
    let activeDurationMS: Int
    let growthDelta: GrowthDelta
    let growthOverview: GrowthOverviewDTO

    enum CodingKeys: String, CodingKey {
        case ordinal
        case completionRate = "completion_rate"
        case activeDurationMS = "active_duration_ms"
        case growthDelta = "growth_delta"
        case growthOverview = "growth_overview"
    }
}

private struct CreateMakeupPlanRequest: Encodable {
    let requestID: String
    let portraitJobID: String
    let styleID: String?
    let scene: String?
    let weather: WeatherContextDTO?

    enum CodingKeys: String, CodingKey {
        case scene, weather
        case requestID = "request_id"
        case portraitJobID = "portrait_job_id"
        case styleID = "style_id"
    }
}

private struct StartMakeupSessionRequest: Encodable {
    let requestID: String
    let planID: String
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case planID = "plan_id"
    }
}

private struct MakeupSessionActionRequest: Encodable {
    let eventID: String
    let stepID: String
    let planVersion: Int
    let kind: String
    let direction: String?
    let committed: Bool?
    let visibleMS: Int
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case kind, direction, committed
        case eventID = "event_id"
        case stepID = "step_id"
        case planVersion = "plan_version"
        case visibleMS = "visible_ms"
        case occurredAt = "occurred_at"
    }
}

private struct CompleteMakeupSessionRequest: Encodable {
    let requestID: String
    let completedAt: String
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case completedAt = "completed_at"
    }
}

struct WeatherContextDTO: Encodable, Sendable {
    let source = "open_meteo"
    let temperatureC: Int
    let condition: String
    let uvIndex: Int
    let district: String
    let observedAt: String

    enum CodingKeys: String, CodingKey {
        case source, condition, district
        case temperatureC = "temperature_c"
        case uvIndex = "uv_index"
        case observedAt = "observed_at"
    }
}

private struct WeatherCopyRequest: Encodable {
    let requestID: String
    let surface: String
    let styleID: String?
    let weather: WeatherContextDTO?

    enum CodingKeys: String, CodingKey {
        case surface, weather
        case requestID = "request_id"
        case styleID = "style_id"
    }
}

private struct CheckInRequest: Encodable {
    let requestID: String
    enum CodingKeys: String, CodingKey { case requestID = "request_id" }
}

private struct PortraitGenerateRequest: Encodable {
    let requestID: String
    let profileVersion: Int
    let consentVersion: String
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case profileVersion = "profile_version"
        case consentVersion = "consent_version"
    }
}

struct PortraitGenerateTicketDTO: Decodable, Sendable {
    let portrait: UserPortraitDTO
    let pollAfterMS: Int
    enum CodingKeys: String, CodingKey {
        case portrait
        case pollAfterMS = "poll_after_ms"
    }
}

private struct CheckInResponse: Decodable {
    let overview: GrowthOverviewDTO
}

private struct BehaviorEventRequest: Encodable {
    let eventID: String
    let eventType: String
    let tipID: String
    let surface: String
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case surface
        case eventID = "event_id"
        case eventType = "event_type"
        case tipID = "tip_id"
        case occurredAt = "occurred_at"
    }
}

private struct EmptyBusinessResponse: Decodable {}

@MainActor
final class BusinessDataService {
    static let shared = BusinessDataService()

    private init() {}

    private func client() throws -> APIClient {
        guard let token = SessionManager.shared.context?.accessToken else {
            throw APIClientError.invalidServerResponse(statusCode: 401, requestID: nil)
        }
        _ = try APIEnvironment.shared.load()
        return try APIEnvironment.shared.authenticatedClient(accessToken: token)
    }

    func growthOverview() async throws -> GrowthOverviewDTO {
        let response: APIEnvelope<GrowthOverviewDTO> = try await client().send(path: "/growth/overview")
        return response.data
    }

    func checkIn(requestID: String) async throws -> GrowthOverviewDTO {
        let response: APIEnvelope<CheckInResponse> = try await client().send(
            path: "/growth/check-ins", body: CheckInRequest(requestID: requestID),
            idempotencyKey: requestID
        )
        return response.data.overview
    }

    func visualProfile() async throws -> UserVisualProfileDTO {
        let response: APIEnvelope<UserVisualProfileDTO> = try await client().send(path: "/users/me/visual-profile")
        return response.data
    }

    func portraitImage(id: String, variant: String) async throws -> Data {
        guard variant == "full" || variant == "avatar" else { throw APIClientError.invalidResponse }
        let response = try await client().downloadResponse(
            path: "/users/me/portraits/\(id)/image?variant=\(variant)",
            expectedContentType: "image/png"
        )
        return response.data
    }

    func generatePortrait(requestID: String, profileVersion: Int) async throws -> PortraitGenerateTicketDTO {
        let response: APIEnvelope<PortraitGenerateTicketDTO> = try await client().send(
            path: "/users/me/portrait/generate",
            body: PortraitGenerateRequest(
                requestID: requestID, profileVersion: profileVersion,
                consentVersion: "portrait-cutout-v1"
            ),
            idempotencyKey: requestID, expectedStatusCode: 202
        )
        return response.data
    }

    func portraitPreviewImage(jobID: String) async throws -> Data {
        let response = try await client().downloadResponse(
            path: "/vision/jobs/\(jobID)/portrait-preview-image", expectedContentType: "image/png"
        )
        return response.data
    }

    func renderResult(jobID: String) async throws -> MakeupRenderResultDTO? {
        let response: APIEnvelope<MakeupRenderJobDTO> = try await client().send(path: "/vision/jobs/\(jobID)")
        let job = response.data
        guard job.jobID == jobID, job.jobType == "makeup_render" else {
            throw APIClientError.invalidResponse
        }
        guard job.status == "succeeded" else { return nil }
        guard let result = job.result, result.resultSource == "remote_provider",
              result.schemaVersion == "1.0", !result.recipeID.isEmpty,
              !result.recipeHash.isEmpty, !result.outputAsset.assetID.isEmpty else {
            throw APIClientError.invalidResponse
        }
        return result
    }

    func renderResultImage(jobID: String) async throws -> Data {
        let response = try await client().downloadResponse(
            path: "/vision/jobs/\(jobID)/result-image", expectedContentType: "image/png"
        )
        return response.data
    }

    func styles() async throws -> [MakeupStyleDTO] {
        let response: APIEnvelope<MakeupStylesDTO> = try await client().send(path: "/makeup/styles")
        return response.data.items
    }

    func cosmetics() async throws -> [CosmeticDTO] {
        var items: [CosmeticDTO] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        repeat {
            var components = URLComponents()
            if let cursor { components.queryItems = [URLQueryItem(name: "cursor", value: cursor)] }
            let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
            let response: APIEnvelope<CosmeticsPageDTO> = try await client().send(path: "/cosmetics\(query)")
            items.append(contentsOf: response.data.items)
            cursor = response.data.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted { throw APIClientError.invalidResponse }
        } while cursor != nil
        return items
    }

    func addCosmetic(_ candidate: CosmeticsRecognitionResult, requestID: String) async throws -> CosmeticDTO {
        let category = CosmeticCategory.from(raw: candidate.category)?.backendValue ?? candidate.category
        let attributes: [String: JSONValue] = [
            "tags": .array(candidate.tags.map(JSONValue.string)),
            "color_hexes": .array(candidate.colorHexes.map(JSONValue.string)),
            "material": .string(candidate.material),
            "summary": .string(candidate.summary)
        ]
        let response: APIEnvelope<CosmeticDTO> = try await client().send(
            path: "/cosmetics",
            body: CreateCosmeticRequest(
                requestID: requestID, sourceJobID: candidate.recognitionID,
                category: category, displayName: candidate.displayName,
                brand: nil, shade: nil, attributes: attributes
            ),
            idempotencyKey: requestID
        )
        return response.data
    }

    func cosmeticImage(id: String) async throws -> Data {
        let response = try await client().downloadResponse(
            path: "/cosmetics/\(id)/image", expectedContentType: "image/png"
        )
        return response.data
    }

    func updateCosmetic(id: String, displayName: String) async throws -> CosmeticDTO {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIClientError.invalidResponse
        }
        let response: APIEnvelope<CosmeticDTO> = try await client().send(
            path: "/cosmetics/\(id)", method: .patch,
            body: UpdateCosmeticRequest(displayName: displayName)
        )
        return response.data
    }

    func deleteCosmetic(id: String) async throws {
        let response: APIEnvelope<DeleteCosmeticResponse> = try await client().send(
            path: "/cosmetics/\(id)", method: .delete
        )
        guard response.data.deleted else { throw APIClientError.invalidResponse }
    }

    func makeupHistory() async throws -> [MakeupHistoryDTO] {
        var items: [MakeupHistoryDTO] = []
        var cursor: String?
        var seenCursors: Set<String> = []
        repeat {
            var components = URLComponents()
            if let cursor { components.queryItems = [URLQueryItem(name: "cursor", value: cursor)] }
            let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
            let response: APIEnvelope<MakeupHistoryPageDTO> = try await client().send(
                path: "/makeup/sessions\(query)"
            )
            items.append(contentsOf: response.data.items)
            cursor = response.data.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted { throw APIClientError.invalidResponse }
        } while cursor != nil
        return items
    }

    func makeupStats() async throws -> MakeupStatsDTO {
        let response: APIEnvelope<MakeupStatsDTO> = try await client().send(path: "/makeup/stats")
        return response.data
    }

    func submitFeedback(sessionID: String, requestID: String, rating: Int) async throws {
        guard (1...5).contains(rating) else { throw APIClientError.invalidResponse }
        let response: APIEnvelope<MakeupFeedbackResponse> = try await client().send(
            path: "/makeup/sessions/\(sessionID)/feedback",
            body: MakeupFeedbackRequest(requestID: requestID, rating: rating, tags: [], comment: nil),
            idempotencyKey: requestID
        )
        guard response.data.rating == rating else { throw APIClientError.invalidResponse }
    }

    func createPlan(
        requestID: String, portraitJobID: String, styleID: String?, weather: WeatherContextDTO?
    ) async throws -> MakeupPlanTicketDTO {
        let response: APIEnvelope<MakeupPlanTicketDTO> = try await client().send(
            path: "/makeup/plans",
            body: CreateMakeupPlanRequest(
                requestID: requestID, portraitJobID: portraitJobID, styleID: styleID,
                scene: "daily", weather: weather
            ),
            idempotencyKey: requestID, expectedStatusCode: 202
        )
        return response.data
    }

    func plan(id: String) async throws -> MakeupPlanDTO {
        let response: APIEnvelope<MakeupPlanDTO> = try await client().send(path: "/makeup/plans/\(id)")
        return response.data
    }

    func startSession(requestID: String, planID: String) async throws -> MakeupSessionDTO {
        let response: APIEnvelope<MakeupSessionDTO> = try await client().send(
            path: "/makeup/sessions",
            body: StartMakeupSessionRequest(requestID: requestID, planID: planID),
            idempotencyKey: requestID
        )
        return response.data
    }

    func session(id: String) async throws -> MakeupSessionDTO {
        let response: APIEnvelope<MakeupSessionDTO> = try await client().send(path: "/makeup/sessions/\(id)")
        return response.data
    }

    func action(
        sessionID: String, eventID: String, stepID: String, planVersion: Int,
        kind: String, direction: String?, committed: Bool?, visibleMS: Int
    ) async throws -> MakeupSessionDTO {
        let response: APIEnvelope<MakeupSessionDTO> = try await client().send(
            path: "/makeup/sessions/\(sessionID)/actions",
            body: MakeupSessionActionRequest(
                eventID: eventID, stepID: stepID, planVersion: planVersion,
                kind: kind, direction: direction, committed: committed,
                visibleMS: visibleMS, occurredAt: ISO8601DateFormatter().string(from: .now)
            ),
            idempotencyKey: eventID
        )
        return response.data
    }

    func complete(sessionID: String, requestID: String) async throws -> MakeupCompletionDTO {
        let response: APIEnvelope<MakeupCompletionDTO> = try await client().send(
            path: "/makeup/sessions/\(sessionID)/complete",
            body: CompleteMakeupSessionRequest(
                requestID: requestID,
                completedAt: ISO8601DateFormatter().string(from: .now)
            ),
            idempotencyKey: requestID
        )
        return response.data
    }

    func tip(surface: String, planID: String? = nil, stepID: String? = nil) async throws -> KnowledgeTipDTO.Item? {
        var query = [URLQueryItem(name: "surface", value: surface)]
        if let planID { query.append(URLQueryItem(name: "plan_id", value: planID)) }
        if let stepID { query.append(URLQueryItem(name: "step_id", value: stepID)) }
        var components = URLComponents()
        components.queryItems = query
        let response: APIEnvelope<KnowledgeTipDTO> = try await client().send(
            path: "/knowledge/tip?\(components.percentEncodedQuery ?? "")"
        )
        return response.data.item
    }

    func weatherCopy(surface: String, styleID: String?, weather: WeatherContextDTO?) async throws -> WeatherCopyDTO {
        let requestID = UUID().uuidString
        let response: APIEnvelope<WeatherCopyDTO> = try await client().send(
            path: "/assistant/weather-copy",
            body: WeatherCopyRequest(requestID: requestID, surface: surface, styleID: styleID, weather: weather),
            idempotencyKey: requestID
        )
        return response.data
    }

    func recordTipEvent(_ item: KnowledgeTipDTO.Item, surface: String, type: String) async throws {
        guard type == "tip_shown" || type == "tip_dismissed" else { throw APIClientError.invalidResponse }
        let eventID = UUID().uuidString
        let body = BehaviorEventRequest(
            eventID: eventID, eventType: type, tipID: item.id, surface: surface,
            occurredAt: ISO8601DateFormatter().string(from: .now)
        )
        let _: APIEnvelope<EmptyBusinessResponse> = try await client().send(
            path: "/behavior/events", body: body, idempotencyKey: eventID
        )
    }
}

@Observable
@MainActor
final class BusinessStore {
    static let shared = BusinessStore()

    private(set) var accountID: String?
    private(set) var growth: GrowthOverviewDTO?
    private(set) var visualProfile: UserVisualProfileDTO.Profile?
    private(set) var avatarData: Data?
    private(set) var styles: [MakeupStyleDTO] = []
    private(set) var cosmetics: [CosmeticDTO] = []
    private(set) var cosmeticsError: String?
    private(set) var makeupHistory: [MakeupHistoryDTO] = []
    private(set) var makeupStats: MakeupStatsDTO?
    private(set) var statsError: String?
    private(set) var activePlan: MakeupPlanDTO?
    private(set) var activeSession: MakeupSessionDTO?
    private(set) var completion: MakeupCompletionDTO?
    private(set) var growthError: String?
    private(set) var profileError: String?
    private(set) var stylesError: String?
    private(set) var historyError: String?

    func reset(for accountID: String?) {
        self.accountID = accountID
        growth = nil
        visualProfile = nil
        avatarData = nil
        styles = []
        cosmetics = []
        cosmeticsError = nil
        makeupHistory = []
        makeupStats = nil
        statsError = nil
        activePlan = nil
        activeSession = nil
        completion = nil
        growthError = nil
        profileError = nil
        stylesError = nil
        historyError = nil
    }

    func refreshGrowth() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.growthOverview()
            guard accountID == requestedAccount else { return }
            growth = value
            growthError = nil
        } catch {
            guard accountID == requestedAccount else { return }
            growth = nil
            growthError = error.localizedDescription
        }
    }

    func checkInToday() async {
        guard let accountID else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let key = "auraeye.checkin.\(accountID).\(formatter.string(from: .now))"
        let requestID: String
        if let saved = UserDefaults.standard.string(forKey: key) {
            requestID = saved
        } else {
            requestID = UUID().uuidString
            UserDefaults.standard.set(requestID, forKey: key)
        }
        do {
            let overview = try await BusinessDataService.shared.checkIn(requestID: requestID)
            guard self.accountID == accountID else { return }
            growth = overview
            growthError = nil
        } catch {
            await refreshGrowth()
        }
    }

    func refreshProfile() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.visualProfile()
            guard accountID == requestedAccount else { return }
            visualProfile = value.profile
            profileError = nil
            if let portrait = value.profile?.portrait,
               portrait.status == "succeeded", portrait.hasAlpha {
                let image = try? await BusinessDataService.shared.portraitImage(
                    id: portrait.portraitID, variant: "avatar"
                )
                guard accountID == requestedAccount else { return }
                avatarData = image
            } else {
                avatarData = nil
            }
        } catch {
            guard accountID == requestedAccount else { return }
            visualProfile = nil
            avatarData = nil
            profileError = error.localizedDescription
        }
    }

    func refreshStyles() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.styles()
            guard accountID == requestedAccount else { return }
            styles = value
            stylesError = nil
        } catch {
            guard accountID == requestedAccount else { return }
            styles = []
            stylesError = error.localizedDescription
        }
    }

    func refreshCosmetics() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.cosmetics()
            guard accountID == requestedAccount else { return }
            cosmetics = value
            cosmeticsError = nil
        } catch {
            guard accountID == requestedAccount else { return }
            cosmetics = []
            cosmeticsError = error.localizedDescription
        }
    }

    func refreshHistory() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.makeupHistory()
            guard accountID == requestedAccount else { return }
            makeupHistory = value
            historyError = nil
        } catch {
            guard accountID == requestedAccount else { return }
            makeupHistory = []
            historyError = error.localizedDescription
        }
    }

    func restoreActivePractice() async {
        let requestedAccount = accountID
        guard let entry = makeupHistory.first(where: { $0.status == "in_progress" }) else { return }
        do {
            async let plan = BusinessDataService.shared.plan(id: entry.planID)
            async let practice = BusinessDataService.shared.session(id: entry.sessionID)
            let (resolvedPlan, resolvedPractice) = try await (plan, practice)
            guard accountID == requestedAccount,
                  resolvedPlan.planID == entry.planID,
                  resolvedPractice.sessionID == entry.sessionID,
                  resolvedPractice.status == "in_progress" else { return }
            activePlan = resolvedPlan
            activeSession = resolvedPractice
        } catch {
            // History remains visible; the user can retry after the service recovers.
        }
    }

    func refreshStats() async {
        let requestedAccount = accountID
        guard requestedAccount != nil else { return }
        do {
            let value = try await BusinessDataService.shared.makeupStats()
            guard accountID == requestedAccount else { return }
            makeupStats = value
            statsError = nil
        } catch {
            guard accountID == requestedAccount else { return }
            makeupStats = nil
            statsError = error.localizedDescription
        }
    }

    func install(plan: MakeupPlanDTO) {
        activePlan = plan
        activeSession = nil
        completion = nil
    }

    func install(session: MakeupSessionDTO) {
        activeSession = session
    }

    func install(completion: MakeupCompletionDTO) {
        guard completion.growthDelta.levelAfter == completion.growthOverview.level else { return }
        self.completion = completion
        growth = completion.growthOverview
    }
}
