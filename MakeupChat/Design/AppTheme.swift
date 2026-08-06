import SwiftUI

/// iOS HIG 语义化设计令牌：字体、图标、颜色、动效
enum AppTheme {
    // MARK: - Corner Radius（与 Figma 圆角层级一致）

    enum CornerRadius {
        /// 提示条、小标签
        static let label: CGFloat = 4
        /// 图片与小型视觉容器
        static let image: CGFloat = 8
        /// 头像缩略图、工具预览
        static let thumbnail: CGFloat = 12
        /// 操作按钮
        static let button: CGFloat = 16
        /// 标准内容卡片
        static let card: CGFloat = 18
        /// 天气、引导等主卡片
        static let hero: CGFloat = 24
    }

    // MARK: - Typography（Dynamic Type 友好）

    enum Typography {
        static let screenTitle = Font.system(.title2, design: .rounded).weight(.regular)
        static let cardTitle = Font.system(.callout, design: .default).weight(.light)
        static let cardSubtitle = Font.system(.caption, design: .default).weight(.light)
        static let stepLabel = Font.system(.callout, design: .default).weight(.semibold)
        static let buttonLabel = Font.system(.caption, design: .default).weight(.semibold)
        static let tipTag = Font.system(.caption, design: .rounded)
        static let statusBar = Font.system(.caption, design: .default).weight(.light)
        static let body = Font.body
    }

    // MARK: - SF Symbols（与 Figma 图标语义对齐）

    enum Symbol {
        static let back = "chevron.left"
        static let menu = "line.3.horizontal"
        static let sparkle = "sparkles"
        static let search = "magnifyingglass"
        static let userProfile = "person.crop.circle.fill"
        static let cosmetics = "shippingbox.fill"
        static let makeupGenerate = "wand.and.stars"
        static let camera = "camera.fill"
        static let checkmark = "checkmark.circle.fill"
        static let home = "house.fill"
        static let cabinet = "square.grid.2x2"
        static let profile = "person.fill"
    }

    // MARK: - Colors

    enum ColorToken {
        static let textPrimary = Color(red: 0.15, green: 0.15, blue: 0.15)
        static let textSecondary = Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75)
        static let accentCoral = Color(red: 1.0, green: 0.60, blue: 0.49)
        static let accentOrange = Color(red: 0.99, green: 0.49, blue: 0.33)
        static let stepActive = Color(red: 1.0, green: 0.88, blue: 0.85)
        static let stepCompleted = Color(red: 1.0, green: 154 / 255, blue: 124 / 255)
        static let stepPending = Color(red: 0.85, green: 0.85, blue: 0.85)
        static let cardFill = Color.white.opacity(0.4)
        static let buttonPrimary = Color(red: 0.15, green: 0.15, blue: 0.15)
        static let buttonDisabled = Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.55)
        static let buttonSuccess = Color(red: 1.0, green: 154 / 255, blue: 124 / 255)
    }

    // MARK: - Motion（系统弹簧曲线）

    enum Motion {
        static let stepSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
        static let quickSpring = Animation.spring(response: 0.32, dampingFraction: 0.78)
        static let statusFade = Animation.easeInOut(duration: 0.25)
    }
}
