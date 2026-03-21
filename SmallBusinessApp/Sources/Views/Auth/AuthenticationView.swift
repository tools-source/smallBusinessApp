import AuthenticationServices
import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case login = "Log In"
    case signUp = "Sign Up"

    var id: String { rawValue }

    func title(for role: UserRole) -> String {
        switch (self, role) {
        case (.login, .worker): return "Worker Login"
        case (.login, .business): return "Business Login"
        case (.signUp, .worker): return "Create Worker Account"
        case (.signUp, .business): return "Create Business Account"
        }
    }

    func subtitle(for role: UserRole) -> String {
        switch self {
        case .login:
            return role.subtitle
        case .signUp:
            switch role {
            case .worker:
                return "Create a worker account to apply for jobs and build your rating."
            case .business:
                return "Create a business account to hire workers and build your rating."
            }
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var portal: UserRole = .worker
    @State private var mode: AuthMode = .login
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var feedbackMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    hero
                    formCard
                    appleButton
                    if !feedbackMessage.isEmpty {
                        feedbackPanel
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.vertical, 24)
            }
            .background(AppChromeBackground())
            .navigationBarTitleDisplayMode(.inline)
            .appKeyboardDismissable()
        }
    }

    private var hero: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 18) {
                AppBadge(title: portal.title, systemImage: portal.icon, tint: AppTint.role(portal))

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HireLocal")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text(mode.title(for: portal))
                            .font(.title3.weight(.semibold))

                        Text(mode.subtitle(for: portal))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTint.role(portal).opacity(0.22),
                                        AppTheme.warmSand.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)

                        Image(systemName: portal.icon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppTint.role(portal))
                    }
                }

                HStack(spacing: 10) {
                    AppBadge(title: "Local jobs", systemImage: "mappin.and.ellipse", tint: .accentColor)
                    AppBadge(title: "Trusted ratings", systemImage: "star.fill", tint: AppTheme.warmSand)
                    AppBadge(title: "Fast inbox", systemImage: "tray.full.fill", tint: .green)
                }
            }
        }
    }

    private var portalSelector: some View {
        VStack(spacing: 14) {
            AppSectionHeader(
                eyebrow: "Portal",
                title: "Choose your workspace",
                subtitle: "Workers apply and build trust. Businesses post openings and manage applicants."
            )

            HStack(spacing: 12) {
                ForEach(UserRole.allCases) { role in
                    Button {
                        portal = role
                        feedbackMessage = ""
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            AppBadge(title: role.title, systemImage: role.icon, tint: AppTint.role(role))

                            Text(role.portalTitle)
                                .font(.headline.weight(.semibold))

                            Text(role.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(portal == role ? AppTint.role(role).opacity(0.16) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    portal == role ? AppTint.role(role).opacity(0.34) : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var modeSelector: some View {
        Picker("Mode", selection: $mode) {
            ForEach(AuthMode.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            feedbackMessage = ""
            password = ""
        }
    }

    private var formCard: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                portalSelector

                modeSelector

                Divider()
                    .opacity(0.45)

                AppSectionHeader(
                    eyebrow: mode == .login ? "Welcome Back" : "Create Account",
                    title: manualActionTitle,
                    subtitle: mode == .login
                        ? "Use your saved email and password for this portal."
                        : "Create your account with the details people in HireLocal will see."
                )

                if mode == .signUp {
                    fieldBlock(title: portal.accountNameLabel) {
                        TextField(portal.accountNameLabel, text: $fullName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .appFieldStyle()
                    }
                }

                fieldBlock(title: "Email") {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appFieldStyle()
                }

                fieldBlock(title: "Password") {
                    SecureField("At least 6 characters", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appFieldStyle()
                }

                Button(manualActionTitle) {
                    submitManualAuth()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
    }

    private var appleButton: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    eyebrow: "Apple Sign In",
                    title: "Use your Apple account",
                    subtitle: "Best when you want faster access or prefer not to manage a password here."
                )

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Continue with Apple for the \(portal.title.lowercased()) portal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var feedbackPanel: some View {
        AppPanel {
            Text(feedbackMessage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var manualActionTitle: String {
        switch mode {
        case .login:
            return "Log In as \(portal.title)"
        case .signUp:
            return "Create \(portal.title) Account"
        }
    }

    private func submitManualAuth() {
        do {
            switch mode {
            case .login:
                try store.login(email: email, password: password, role: portal)
            case .signUp:
                try store.signUp(fullName: fullName, email: email, password: password, role: portal)
            }
            if let currentUser = store.currentUser,
               !currentUser.postingProfileIsComplete || currentUser.marketplaceEmail == nil {
                store.selectedTab = .account
            }
            feedbackMessage = ""
            clearFields()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                feedbackMessage = "Could not read Apple account credentials."
                return
            }
            do {
                try store.signInWithApple(
                    userID: credential.user,
                    fullName: credential.fullName,
                    email: credential.email,
                    role: portal
                )
                if let currentUser = store.currentUser,
                   !currentUser.postingProfileIsComplete || currentUser.marketplaceEmail == nil {
                    store.selectedTab = .account
                }
                feedbackMessage = ""
                clearFields()
            } catch {
                feedbackMessage = error.localizedDescription
            }
        case .failure(let error):
            feedbackMessage = appleSignInMessage(for: error)
        }
    }

    private func clearFields() {
        fullName = ""
        email = ""
        password = ""
    }

    private func fieldBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func appleSignInMessage(for error: Error) -> String {
        guard let authorizationError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authorizationError.code {
        case .canceled:
            return "Apple Sign In was canceled."
        case .invalidResponse:
            return "Apple Sign In returned an invalid response. Try again."
        case .notHandled:
            return "Apple Sign In could not be completed on this device right now."
        case .failed:
            return "Apple Sign In failed. Make sure this device is signed into an Apple Account and try again."
        case .notInteractive:
            return "Apple Sign In needs an interactive device session. Unlock the device and try again."
        case .unknown:
            return "Apple Sign In is not fully configured for this build. In Xcode, confirm Signing uses your Apple Developer team and the target has the Sign in with Apple capability enabled."
        case .matchedExcludedCredential,
             .credentialImport,
             .credentialExport,
             .preferSignInWithApple,
             .deviceNotConfiguredForPasskeyCreation:
            return "Apple Sign In could not be completed with the current device credential setup. Check the device Apple account and try again."
        @unknown default:
            return "Apple Sign In could not be completed. Check the app's signing and capability setup in Xcode and try again."
        }
    }
}
