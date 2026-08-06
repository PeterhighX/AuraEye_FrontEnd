import Foundation

extension CosmeticItem {
    /// 展示名称 — 后台识别接入后由 `brush_json.name` 或识别结果填充
    var displayName: String {
        if let name = brushMetadata?["name"] as? String, !name.isEmpty {
            return name
        }
        if sku.hasPrefix("scan_") {
            return "\(CosmeticCategory.normalize(makeupCategory))产品"
        }
        return sku.replacingOccurrences(of: "_", with: " ")
    }

    var tags: [String] {
        if let makeupTab,
           makeupTab.hasPrefix("["),
           let data = makeupTab.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return array
        }
        if let makeupTab, !makeupTab.isEmpty {
            return [makeupTab]
        }
        return []
    }

    /// 品牌色值 — 后台识别后写入 `makeup_colors`
    var colorHexes: [String] {
        guard
            let makeupColorsJSON,
            let data = makeupColorsJSON.data(using: .utf8),
            let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return array
    }

    var category: CosmeticCategory? {
        CosmeticCategory.from(raw: makeupCategory)
    }

    var colorFamilyText: String {
        tags.first ?? "待模型分析色系"
    }

    var materialText: String {
        if let material = brushMetadata?["material"] as? String, !material.isEmpty {
            return material
        }
        return tags.first ?? "待模型分析材质"
    }

    var summaryText: String {
        if let summary = brushMetadata?["summary"] as? String, !summary.isEmpty {
            return summary
        }
        if tags.count > 1 {
            return tags[1]
        }
        return category == .eyeliner ? "顺滑显色，适合勾勒眼线" : "柔软抓粉，适合自然晕染"
    }

    private var brushMetadata: [String: Any]? {
        guard
            let brushJSON,
            let data = brushJSON.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }
}
