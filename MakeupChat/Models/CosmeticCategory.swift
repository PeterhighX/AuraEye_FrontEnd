import SwiftUI

/// 陈列柜分区 — 与后台 `makeup_cat` 对齐
enum CosmeticCategory: String, CaseIterable, Identifiable {
    case eyeshadow = "眼影"
    case eyeliner = "眼线"
    case brush = "毛刷"

    var id: String { rawValue }

    /// AuraEye 视觉接口的稳定类别枚举。
    var backendValue: String {
        switch self {
        case .eyeshadow: return "eyeshadow_palette"
        case .eyeliner: return "eyeliner"
        case .brush: return "makeup_brush"
        }
    }

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
        let value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        if [
            "眼影", "眼影盘", "eyeshadow", "eye shadow", "eye shadow palette",
            "eyeshadow palette", "palette", "eyeshadow_palette"
        ].contains(value) {
            return CosmeticCategory.eyeshadow.rawValue
        }

        if [
            "眼线", "眼线笔", "眼线液笔", "eyeliner", "eye liner",
            "eyeliner pencil", "liquid eyeliner"
        ].contains(value) {
            return CosmeticCategory.eyeliner.rawValue
        }

        if [
            "毛刷", "刷子", "化妆刷", "眼影刷", "brush", "makeup brush",
            "cosmetic brush", "eye brush", "makeup_brush"
        ].contains(value) {
            return CosmeticCategory.brush.rawValue
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func from(raw: String) -> CosmeticCategory? {
        let normalized = normalize(raw)
        return CosmeticCategory.allCases.first { $0.rawValue == normalized }
    }
}
