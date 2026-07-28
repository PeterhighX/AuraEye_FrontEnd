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

    private let userRepository: UserRepository
    private let cosmeticsRepository: CosmeticsRepository
    private let recognitionService: any CosmeticsRecognitionServicing

    init(
        userRepository: UserRepository = UserRepository(),
        cosmeticsRepository: CosmeticsRepository = CosmeticsRepository(),
        recognitionService: any CosmeticsRecognitionServicing = CosmeticsRecognitionService()
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
            let key = CosmeticCategory.from(raw: item.makeupCategory) ?? .eyeshadow
            grouped[key, default: []].append(item)
        }

        sections = CosmeticCategory.allCases.map { category in
            CabinetSection(category: category, items: grouped[category] ?? [])
        }
    }

    func recognizeProduct(image: UIImage, categoryHint: CosmeticCategory?) async {
        isRecognizing = true
        defer { isRecognizing = false }

        do {
            pendingProduct = try await recognitionService.recognize(
                image: image,
                categoryHint: categoryHint?.rawValue
            )
        } catch {
            // 识别失败时仍保留本地流程，后续可接错误提示
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
            return false
        }
    }

    func rejectPendingProduct() {
        pendingProduct = nil
    }
}
