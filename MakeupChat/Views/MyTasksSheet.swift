import SwiftUI

/// Figma 20:1512 — 叠在「我的」页上的任务弹层
struct MyTasksSheet: View {
    let tasks: [UserTaskItem]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            taskList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(spacing: 8) {
                Text("我的任务")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))

                Text("完成任务可获得闪闪的奖励哦，用户等级越高获得积分越多哦")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func taskRow(_ task: UserTaskItem) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(task.isCompleted ? AppTheme.ColorToken.accentOrange : Color.clear)
                .overlay {
                    Circle()
                        .stroke(
                            task.isCompleted ? AppTheme.ColorToken.accentOrange : Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.25),
                            lineWidth: task.isCompleted ? 0 : 1.5
                        )
                }
                .frame(width: 12, height: 12)

            Text(task.title)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accentOrange)
                Text("\(task.reward)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(minHeight: 78)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 0.1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    MyTasksSheet(tasks: ProfileViewModel.defaultTasks, onClose: {})
}
