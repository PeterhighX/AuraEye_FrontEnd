import SwiftUI

/// 妆容步骤文案统一排版；内容由妆容计划接口返回。
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
