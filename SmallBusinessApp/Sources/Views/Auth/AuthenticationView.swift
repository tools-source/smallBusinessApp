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
                VStack(spacing: 20) {
                    hero
                    portalSelector
                    modeSelector
                    formCard
                    appleButton
                    if !feedbackMessage.isEmpty {
                        Text(feedbackMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color("BrandBackground").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: portal.icon)
                .font(.system(size: 54))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.accentColor, .white)

            Text("HireLocal")
                .font(.largeTitle.bold())

            Text(mode.title(for: portal))
                .font(.title3.weight(.semibold))

            Text(mode.subtitle(for: portal))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var portalSelector: some View {
        HStack(spacing: 12) {
            ForEach(UserRole.allCases) { role in
                Button {
                    portal = role
                    feedbackMessage = ""
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: role.icon)
                            .font(.headline)
                        Text(role.portalTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(portal == role ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                    .foregroundStyle(portal == role ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                portal == role ? Color.clear : Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
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
        VStack(spacing: 14) {
            if mode == .signUp {
                TextField(portal.accountNameLabel, text: $fullName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Button(manualActionTitle) {
                submitManualAuth()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04), lineWidth: 1)
        }
    }

    private var appleButton: some View {
        VStack(spacing: 10) {
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: 375)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Continue with Apple for the \(portal.title.lowercased()) portal")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                   (currentUser.role == .business && !currentUser.businessProfileIsComplete)
                    || currentUser.marketplaceEmail == nil {
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
