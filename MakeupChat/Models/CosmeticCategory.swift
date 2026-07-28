import SwiftUI

/// 陈列柜分区 — 与后台 `makeup_cat` 对齐
enum CosmeticCategory: String, CaseIterable, Identifiable {
    case eyeshadow = "眼影"
    case eyeliner = "眼线"
    case brush = "毛刷"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .eyeshadow: return Color(red: 0.99, green: 0.49, blue: 0.33)
        case .eyeliner: return Color(red: 0.58, green: 0.59, blue: 1.0)
        case .brush: return Color(red: 0.96, green: 0.62, blue: 0.83)
        }
    }

    var placeholderSymbol: String {
        switch self {
        case .eyeshadow: return "paintpalette.fill"
        case .eyeliner: return "pencil.line"
        case .brush: return "paintbrush.pointed.fill"
        }
    }

    static func normalize(_ raw: String) -> String {
        if raw == "刷子" { return CosmeticCategory.brush.rawValue }
        return raw
    }

    static func from(raw: String) -> CosmeticCategory? {
        let normalized = normalize(raw)
        return CosmeticCategory.allCases.first { $0.rawValue == normalized }
    }
}
