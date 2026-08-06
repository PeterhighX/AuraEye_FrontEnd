import Foundation
import SwiftUI

struct MakeupInstructionStep: Identifiable {
    let id: Int
    let title: String
    let tool: String
    let instruction: String
    let tip: String
    let previewAsset: String
}

struct MakeupLookPlan: Identifiable {
    let id: String
    let look: HomeRecommendedLook
    let summary: String
    let steps: [MakeupInstructionStep]
}

enum MakeupLookCatalog {
    static let plans: [MakeupLookPlan] = [
        MakeupLookPlan(
            id: "clear_sweet",
            look: HomeRecommendedLook(
                id: "clear_sweet", title: "清透甜美", tag: "少女感",
                imageAssetName: "HomeLookClearFocus",
                swatchHexes: ["#C87A72", "#CE8C80", "#DCADA0"]
            ),
            summary: "适合日常出行，妆容简单，5分钟画完",
            steps: [
                step(1, "打底铺色", "大号铺色刷", "咱们先保持眼部干燥，拿一把【大号铺色刷】沾取【哑光蜜桃粉肉色】，在整个上眼皮大面积铺色打底。手法一定要轻，少量多次地【叠加】，把眼皮上的暗沉和油脂都盖住。", "注意边缘晕染自然哦，别留边界线~"),
                step(2, "修容&阴影", "中号晕染刷", "换一把【中号晕染刷】，沾取【哑光枯玫瑰色】，在眼窝凹陷处和眼尾后三分之一处【加深】。手法要从睫毛根部开始，像画小扇子一样向上、向外轻轻【晕染】开。", "注意飞粉弄脏妆容哦，抓粉后在手背上敲一下再上眼~"),
                step(3, "眼睑下至", "扁头细节刷", "拿一把【扁头细节刷】，沾取【肉桂红棕色眼影】，顺着下睫毛根部后半段【平行往外拉】。再用一把【干净的晕染刷】把下边缘【轻轻揉开】。", "不晕染看着会有一些生硬，稍微揉一下就是妈生大眼~"),
                step(4, "卧蚕", "刀锋刷", "微微微笑一下，用【刀锋刷】沾取【浅冷棕色】，在眼下褶皱处轻轻画一条阴影线，【两边淡化】。接着用一把【小号细节刷】，沾取【哑光香槟肤色】，精准涂在卧蚕正中间【提亮】。", "这样能得到一个饱满立体的卧蚕，笑起来超好看~"),
                step(5, "双眼皮与眼线", "刀锋刷", "在闭眼时的眼褶上方贴好双眼皮贴，用【刀锋刷】蘸取【深棕色】，紧贴睫毛根部，在眼尾指定位置顺势拉出一条流畅的微挑线条，并把睫毛根部的空隙填满。", "恭喜你获得今日份完美妆容，清透又消肿！")
            ]
        ),
        MakeupLookPlan(
            id: "chinese_warm",
            look: HomeRecommendedLook(
                id: "chinese_warm", title: "中式温婉", tag: "东方韵味",
                imageAssetName: "HomeLookWarmFocus",
                swatchHexes: ["#C15C40", "#C26947", "#EEAC9B"]
            ),
            summary: "适合通勤约会，暖棕柔和，8分钟画完",
            steps: [
                step(1, "打底铺色", "大号散毛铺色刷", "咱们先保持眼部干燥，拿一把【大号散毛铺色刷】沾取【哑光暖少许杏色】，在整个上眼皮大面积进行大范围铺色打底，轻轻带过下眼睑，先把眼皮的油脂和暗沉盖住。", "注意边缘晕染自然哦，别留边界线~"),
                step(2, "修容与添加阴影色", "中号晕染刷", "换一把【中号晕染刷】，沾取【哑光焦糖正棕色】，在双眼皮褶皱内和眼尾后三分之一的倒三角区进行【加深】。手法要从睫毛根部开始，像画小扇子一样向上、向眼头【轻轻过渡】。", "注意飞粉弄脏妆容哦，抓粉后在手背上敲一下再上眼~"),
                step(3, "眼睑下至", "扁头细节刷", "拿一把【扁头细节刷】，沾取【深可可棕色眼影】，顺着下睫毛根部后半段的提示线【平行往外拉】。再用一把【干净的晕染刷】，把这条线的下边缘轻轻往下揉开。", "不晕染看着会有一些生硬，稍微揉一下就是妈生大眼~"),
                step(4, "卧蚕", "细节扁头刷", "微微微笑一下，用【细节扁头刷】沾取【浅麦芽色】，在眼下褶皱的提示线上轻轻拉出一条自然的阴影线。接着用【小号细节刷】沾取【微珠光低调米金色】，精准涂在卧蚕正中间进行【提亮】。", "这样能得到一个饱满立体的卧蚕，笑起来超好看~"),
                step(5, "双眼皮与眼线", "刀锋刷", "在指定提示范围内贴好双眼皮贴，拿一把【刀锋刷】蘸取【深咖色眼影膏】，紧贴睫毛根部，在眼尾拉出一条平行的轻熟感线条，并把睫毛根部的空隙填满。", "眼尾保持平缓延伸，能让整体气质更加温婉~")
            ]
        ),
        MakeupLookPlan(
            id: "hong_kong",
            look: HomeRecommendedLook(
                id: "hong_kong", title: "气质港风", tag: "复古范",
                imageAssetName: "HomeLookHongKongFocus",
                swatchHexes: ["#9E3819", "#D16234", "#E7936A"]
            ),
            summary: "适合聚会拍照，复古利落，10分钟画完",
            steps: [
                step(1, "打底铺色", "大号羊毛眼影刷", "宝子们保持眼部清爽，用【大号羊毛眼影刷】抓取【哑光复古红棕色】，在提示的眼窝大范围内进行大面积的打底。手法一定要少量多次，【逐渐叠加】出浓郁的底色。", "注意边缘晕染自然哦，范围可以微微向眉毛方向延伸~"),
                step(2, "修容与添加阴影色", "中号火苗头晕染刷", "使用【中号火苗头晕染刷】，蘸取【哑光黑巧克力色】，重点加深眼尾后半段的深邃三角区，从睫毛根部向上、向内眼角方向进行结构性的【结构晕染】。", "注意飞粉弄脏妆容哦，边缘一定要揉得软乎乎的，打造出烟熏的渐层感~"),
                step(3, "眼睑下至", "扁头细节刷", "拿一把【扁头细节刷】，沾取【深可可棕色眼影】，顺着下睫毛根部后半段【平行往外拉】。再用一把【干净的晕染刷】把下边缘【轻轻揉开】。", "不晕染看着会有一些生硬，揉开才会有戏剧性的混血深邃感~"),
                step(4, "卧蚕", "扁头刀锋刷", "咱们眯眼笑一下，用【扁头刀锋刷】蘸取【暗灰棕色】，在眼下卧蚕提示线上轻轻拖出一条大气的线条。再用【指腹】蘸取【爆闪细钻碎银色】，大范围点涂在眼头到眼腹的正中央进行【提亮】。", "这样能得到一个饱满立体的卧蚕，让大五官的视觉重心更加聚焦、更加迷人~"),
                step(5, "双眼皮与眼线", "液体眼线笔", "在闭眼时的指定提示范围内贴好支撑力强的双眼皮贴，用【液体眼线笔】在眼尾指定位置顺着眼型拉出一条微微上扬、干练坚挺的【猫眼眼线】，并快速将尾端【填充饱满】。", "液体眼线成膜较快，先确定眼尾方向再快速填充~")
            ]
        )
    ]

    static func plan(id: String) -> MakeupLookPlan {
        plans.first(where: { $0.id == id }) ?? plans[0]
    }

    private static func step(
        _ id: Int,
        _ title: String,
        _ tool: String,
        _ instruction: String,
        _ tip: String
    ) -> MakeupInstructionStep {
        MakeupInstructionStep(
            id: id,
            title: title,
            tool: tool,
            instruction: instruction,
            tip: tip,
            previewAsset: "PracticeStep\(id)"
        )
    }
}

/// 妆容步骤文案统一排版：`【】` 内是化妆工具、化妆品或关键手法，
/// 在预览与正式跟练页面中使用相同的主题强调，切换妆容时样式不会丢失。
func styledMakeupInstruction(
    _ content: String,
    bullet: Bool = false,
    highlightColor: Color = AppTheme.ColorToken.accentCoral
) -> Text {
    var remaining = content[...]
    var output = Text(bullet ? "• " : "")

    while let opening = remaining.firstIndex(of: "【"),
          let closing = remaining[opening...].firstIndex(of: "】") {
        let ordinary = remaining[..<opening]
        let emphasized = remaining[opening...closing]
        output = output
            + Text(String(ordinary))
            + Text(String(emphasized))
                .fontWeight(.semibold)
                .foregroundColor(highlightColor)
        remaining = remaining[remaining.index(after: closing)...]
    }

    return output + Text(String(remaining))
}
