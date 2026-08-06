import SwiftUI
import UIKit

struct LoginView: View {
    @Bindable var viewModel: LoginViewModel
    var onLogin: (AuthenticatedAccount) -> Void

    @FocusState private var focusedField: Field?
    @State private var passwordVisible = false
    @State private var page: Page = .methods
    @State private var showsWeChatNotice = false

    private enum Page {
        case methods
        case credentials
    }

    private enum Field {
        case account
        case password
    }

    var body: some View {
        ZStack {
            Group {
                if page == .methods {
                    methodSelection
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    credentialPage
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeInOut(duration: 0.32), value: page)
        .alert(
            "登录失败",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("知道了", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "请稍后重试。")
        }
        .alert("微信登录", isPresented: $showsWeChatNotice) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("微信授权接口将在后续接入。")
        }
    }

    private var methodSelection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 88)

            Image("AuraAyeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 154, height: 160)
                .shadow(color: AppTheme.ColorToken.accentCoral.opacity(0.16), radius: 18, y: 8)
                .accessibilityLabel("AuraAye 沐瞳")

            Spacer()

            VStack(spacing: 20) {
                Button {
                    withAnimation {
                        page = .credentials
                    }
                } label: {
                    Label("账号密码登录", systemImage: "person.crop.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(themeButtonBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showsWeChatNotice = true
                } label: {
                    Label("微信登录", systemImage: "message.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.ColorToken.textPrimary)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)

                agreement
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private var credentialPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: returnToMethods) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 12)

                appIcon
                    .padding(.top, 16)

                loginCard
                    .padding(.top, 34)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var appIcon: some View {
        Image("LoginThemeIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 104, height: 104)
            .shadow(color: AppTheme.ColorToken.accentCoral.opacity(0.16), radius: 18, y: 8)
    }

    private var themeButtonBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.ColorToken.accentCoral,
                        Color(red: 1.0, green: 126 / 255, blue: 94 / 255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: AppTheme.ColorToken.accentCoral.opacity(0.28), radius: 12, y: 6)
    }

    private var agreement: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.ColorToken.accentCoral)
            Text("登录即表示你已阅读并同意《用户协议》和《隐私政策》")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("账号密码")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Text("登录后体验更多功能")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                inputField(
                    title: "账号",
                    systemImage: "person",
                    field: .account
                ) {
                    TextField("请输入账号", text: $viewModel.account)
                        .focused($focusedField, equals: .account)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                inputField(
                    title: "密码",
                    systemImage: "lock",
                    field: .password
                ) {
                    Group {
                        if passwordVisible {
                            TextField("请输入密码", text: $viewModel.password)
                                .focused($focusedField, equals: .password)
                        } else {
                            SecureField("请输入密码", text: $viewModel.password)
                                .focused($focusedField, equals: .password)
                        }
                    }
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit(performLogin)

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }

            Button(action: performLogin) {
                HStack(spacing: 10) {
                    if viewModel.isLoggingIn {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isLoggingIn ? "正在进入…" : "登录")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 126 / 255, blue: 94 / 255),
                            Color(red: 1.0, green: 154 / 255, blue: 124 / 255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: Color(red: 1.0, green: 126 / 255, blue: 94 / 255).opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoggingIn)
        }
        .padding(24)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
    }

    private func inputField<Content: View>(
        title: String,
        systemImage: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(focusedField == field ? AppTheme.ColorToken.accentCoral : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    content()
                }
                .font(.system(size: 15))
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 64)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == field
                        ? AppTheme.ColorToken.accentCoral.opacity(0.85)
                        : Color.black.opacity(0.07),
                    lineWidth: focusedField == field ? 1.2 : 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { focusedField = field }
    }

    private func performLogin() {
        guard !viewModel.isLoggingIn else { return }
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        Task {
            if let account = await viewModel.login() {
                // 等待系统键盘完成退出窗口后再切换根页面，避免 UIKit 对已离屏的
                // UIKeyboardImpl 做 snapshot 而输出 afterScreenUpdates 警告。
                try? await Task.sleep(for: .milliseconds(320))
                onLogin(account)
            }
        }
    }

    private func returnToMethods() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        withAnimation {
            page = .methods
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel()) { _ in }
}
