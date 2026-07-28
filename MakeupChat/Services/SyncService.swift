import Foundation

/// `后端数据库.md` v1.0 对应的后端边界。
/// 接入阿里云后新增远端实现并注入，前端 ViewModel 无需感知传输方式。
protocol BackendSyncServicing {
    func pushUser(_ payload: BackendUserPayload) async throws
    func uploadMedia(_ payload: BackendMediaPayload) async throws -> String
    func fetchEyeStyles(scene: String?) async throws -> [BackendEyeStylePayload]
    func pushCosmetic(_ payload: BackendCosmeticPayload) async throws
}

struct BackendUserPayload: Sendable {
    let userId: String
    let userFile: String?
    let userPortrait: String?
    let userUpdatePhoto: String?
    let eyePreview: String?
    let eyeSteps: [String]
}

struct BackendMediaPayload: Sendable {
    enum Field: String, Sendable {
        case userPortrait = "User_potrit"
        case userUpdatePhoto = "User_update_photo"
        case eyePreview = "Eye_Preview"
    }

    let userId: String
    let field: Field
    let base64: String
}

struct BackendEyeStylePayload: Sendable {
    let eyeStyleName: String
    let eyeSVG: String?
    let eyelinerName: String?
    let eyelinerSVG: String?
    let mainColor: String?
    let secondaryColor: String?
    let scene: String?
}

struct BackendCosmeticPayload: Sendable {
    let sku: String
    let category: String
    let tags: [String]
    let colors: [String]
    let brushJSON: String?
}

enum BackendPlaceholderError: Error {
    case cloudDisabled
}

/// 云端同步占位 — 当前仅走本地 SQLite。
final class SyncService: BackendSyncServicing {
    static let shared = SyncService()

    /// 云端未接入前恒为 false
    var isCloudEnabled: Bool { false }

    private init() {}

    func pushUser(_ payload: BackendUserPayload) async throws {
        guard isCloudEnabled else { return }
        // TODO: PUT /api/users/{payload.userId}
    }

    func uploadMedia(_ payload: BackendMediaPayload) async throws -> String {
        guard isCloudEnabled else { return "" }
        // TODO: POST /api/users/{payload.userId}/media
        return ""
    }

    func fetchEyeStyles(scene: String?) async throws -> [BackendEyeStylePayload] {
        guard isCloudEnabled else { return [] }
        // TODO: GET /api/eye-styles?scene={scene}
        return []
    }

    func pushCosmetic(_ payload: BackendCosmeticPayload) async throws {
        guard isCloudEnabled else { return }
        // TODO: PUT /api/cosmetics/{payload.sku}
    }

    func syncUserIfNeeded(userId: String) async {
        guard isCloudEnabled else { return }
        // TODO: PUT /api/users/{userId}
    }

    func uploadMediaIfNeeded(storedPath: String?, field: String) async {
        guard isCloudEnabled, storedPath != nil else { return }
        // TODO: 读 LocalMediaStore → base64 → POST 云端
    }
}
