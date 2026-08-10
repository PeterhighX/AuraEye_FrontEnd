import Foundation
import Observation
import UIKit

struct CabinetSection: Identifiable {
    let category: CosmeticCategory
    var items: [CosmeticItem]
    var id: String { category.rawValue }
}

@Observable
final class DisplayCabinetViewModel {
    private(set) var user: UserProfile
    private(set) var sections: [CabinetSection] = []
    private(set) var isRecognizing = false
    private(set) var pendingProduct: CosmeticsRecognitionResult?
    private(set) var recognitionErrorMessage: String?
    private(set) var analysisState: AsyncAnalysisState<CosmeticsRecognitionResult> = .idle

    private let userRepository: UserRepository
    private let cosmeticsRepository: CosmeticsRepository
    private let recognitionService: any CosmeticsRecognitionServicing

    init(
        userRepository: UserRepository = UserRepository(),
        cosmeticsRepository: CosmeticsRepository = CosmeticsRepository(),
        recognitionService: any CosmeticsRecognitionServicing = AccountAwareCosmeticsRecognitionService()
    ) {
        self.userRepository = userRepository
        self.cosmeticsRepository = cosmeticsRepository
        self.recognitionService = recognitionService
        self.user = UserProfile(
            userId: "mrs_zhang",
            displayName: "Mrs.Zhang",
            status: "开心",
            credits: 50
        )
        reload()
    }

    func reload() {
        if let loaded = try? userRepository.currentUser() {
            user = loaded
        }

        let items = (try? cosmeticsRepository.fetchAll(userId: user.userId)) ?? []
        var grouped: [CosmeticCategory: [CosmeticItem]] = [:]

        for item in items {
            // 不能识别的历史数据不再默认塞进眼影栏，避免分区污染。
            guard let key = CosmeticCategory.from(raw: item.makeupCategory) else { continue }
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
    func confirmPendingProduct() -> Bool {
        guard let pendingProduct else { return false }
        do {
            try cosmeticsRepository.insertRecognized(
                userId: user.userId,
                result: pendingProduct
            )
            self.pendingProduct = nil
            reload()
            return true
        } catch {
            // 数据库写入失败时保留确认卡，方便用户再次尝试
            recognitionErrorMessage = "化妆品信息已经识别，但保存失败，请再次点击“添加”。"
            return false
        }
    }

    func rejectPendingProduct() {
        pendingProduct = nil
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
