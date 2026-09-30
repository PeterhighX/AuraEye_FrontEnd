import Foundation
import Observation
import UIKit

struct CabinetSection: Identifiable {
    let category: CosmeticCategory
    var items: [CosmeticDTO]
    var id: String { category.rawValue }
}

@Observable
@MainActor
final class DisplayCabinetViewModel {
    private(set) var user: UserProfile
    private(set) var sections: [CabinetSection] = []
    private(set) var isRecognizing = false
    private(set) var pendingProduct: CosmeticsRecognitionResult?
    private(set) var recognitionErrorMessage: String?
    private(set) var analysisState: AsyncAnalysisState<CosmeticsRecognitionResult> = .idle
    private(set) var loadErrorMessage: String?

    private let userRepository: UserRepository
    private let recognitionService: any CosmeticsRecognitionServicing
    private var pendingRequestID: String?

    init(
        userRepository: UserRepository = UserRepository(),
        recognitionService: any CosmeticsRecognitionServicing = AccountAwareCosmeticsRecognitionService()
    ) {
        self.userRepository = userRepository
        self.recognitionService = recognitionService
        self.user = UserProfile(
            userId: SessionManager.shared.context?.userId ?? "",
            displayName: SessionManager.shared.context?.displayName ?? "用户",
            status: ""
        )
        groupCosmetics([])
    }

    func reload() async {
        if let loaded = try? userRepository.currentUser() {
            user = loaded
        }
        await BusinessStore.shared.refreshCosmetics()
        loadErrorMessage = BusinessStore.shared.cosmeticsError
        groupCosmetics(BusinessStore.shared.cosmetics)
    }

    private func groupCosmetics(_ items: [CosmeticDTO]) {
        var grouped: [CosmeticCategory: [CosmeticDTO]] = [:]

        for item in items {
            // 不能识别的历史数据不再默认塞进眼影栏，避免分区污染。
            guard let key = CosmeticCategory.from(raw: item.category) else { continue }
            grouped[key, default: []].append(item)
        }

        sections = CosmeticCategory.allCases.map { category in
            CabinetSection(category: category, items: grouped[category] ?? [])
        }
    }

    func recognizeProduct(image: UIImage, categoryHint: CosmeticCategory?) async {
        await recognizeProduct(
            input: VisionImageInput(image: image),
            categoryHint: categoryHint
        )
    }

    func recognizeProduct(input: VisionImageInput, categoryHint: CosmeticCategory?) async {
        isRecognizing = true
        analysisState = .preparingImage
        recognitionErrorMessage = nil
        defer { isRecognizing = false }

        do {
            analysisState = .submitting
            analysisState = .processing(stage: "item_recognition")
            let result = try await recognitionService.recognize(
                input: input,
                categoryHint: categoryHint?.rawValue
            )
            guard result.hasRequiredProductInformation else {
                throw CosmeticsRecognitionError.incompleteProductInformation
            }
            pendingProduct = result
            pendingRequestID = UUID().uuidString
            analysisState = .succeeded(result)
        } catch let error as VisionAPIError {
            analysisState = .failed(error)
            recognitionErrorMessage = error.localizedDescription
        } catch {
            analysisState = .failed(.resultInvalid)
            recognitionErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func confirmPendingProduct() async -> Bool {
        guard let pendingProduct else { return false }
        do {
            let requestID = pendingRequestID ?? UUID().uuidString
            pendingRequestID = requestID
            _ = try await BusinessDataService.shared.addCosmetic(pendingProduct, requestID: requestID)
            self.pendingProduct = nil
            pendingRequestID = nil
            await reload()
            return true
        } catch {
            // 数据库写入失败时保留确认卡，方便用户再次尝试
            recognitionErrorMessage = "化妆品信息已经识别，但保存失败，请再次点击“添加”。"
            return false
        }
    }

    func rejectPendingProduct() {
        pendingProduct = nil
        pendingRequestID = nil
    }

    func renameProduct(id: String, displayName: String) async {
        do {
            _ = try await BusinessDataService.shared.updateCosmetic(id: id, displayName: displayName)
            await reload()
        } catch {
            recognitionErrorMessage = "商品修改失败：\(error.localizedDescription)"
        }
    }

    func deleteProduct(id: String) async {
        do {
            try await BusinessDataService.shared.deleteCosmetic(id: id)
            await reload()
        } catch {
            recognitionErrorMessage = "商品删除失败：\(error.localizedDescription)"
        }
    }

    func dismissRecognitionError() {
        recognitionErrorMessage = nil
        if case .failed = analysisState { analysisState = .idle }
    }

    func reportInputError(_ error: VisionAPIError) {
        analysisState = .failed(error)
        recognitionErrorMessage = error.localizedDescription
    }
}
