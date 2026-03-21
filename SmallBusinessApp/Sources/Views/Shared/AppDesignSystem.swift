import SwiftUI
import UIKit

enum AppTheme {
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 18
    static let panelPadding: CGFloat = 18
    static let panelRadius: CGFloat = 26
    static let fieldRadius: CGFloat = 18

    static let warmSand = Color(red: 0.86, green: 0.69, blue: 0.44)
    static let mist = Color(red: 0.85, green: 0.92, blue: 0.97)
    static let ink = Color(red: 0.10, green: 0.15, blue: 0.24)
}

enum AppTint {
    static func role(_ role: UserRole) -> Color {
        switch role {
        case .worker:
            return Color.accentColor
        case .business:
            return AppTheme.warmSand
        }
    }

    static func postType(_ postType: PostType) -> Color {
        switch postType {
        case .employerHiring:
            return AppTheme.warmSand
        case .workerSeeking:
            return Color.accentColor
        }
    }

    static func status(_ status: ApplicationStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .reviewed:
            return Color.accentColor
        case .contacted:
            return .purple
        case .hired:
            return .green
        case .declined:
            return .red
        }
    }
}

struct AppChromeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color("BrandBackground")
                .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        AppTheme.ink.opacity(0.62),
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.40)
                    ]
                    : [
                        Color.white.opacity(0.94),
                        AppTheme.mist.opacity(0.48),
                        AppTheme.warmSand.opacity(0.10)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.15))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: -160, y: -250)

            Circle()
                .fill(AppTheme.warmSand.opacity(colorScheme == .dark ? 0.18 : 0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: -180)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.30))
                .frame(width: 420, height: 420)
                .blur(radius: 150)
                .offset(x: 120, y: 320)
        }
    }
}

struct AppPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        padding: CGFloat = AppTheme.panelPadding,
        cornerRadius: CGFloat = AppTheme.panelRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.74))
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.85),
                                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08),
                        radius: 24,
                        x: 0,
                        y: 14
                    )
            }
    }
}

struct AppSectionHeader: View {
    let eyebrow: String?
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppBadge: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [Color.accentColor.opacity(0.85), AppTheme.ink.opacity(0.86)]
                        : [Color.accentColor, AppTheme.ink.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AppFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let verticalPadding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func appFieldStyle(
        verticalPadding: CGFloat = 14,
        cornerRadius: CGFloat = AppTheme.fieldRadius
    ) -> some View {
        modifier(AppFieldModifier(verticalPadding: verticalPadding, cornerRadius: cornerRadius))
    }

    func appPanelStyle(
        padding: CGFloat = AppTheme.panelPadding,
        cornerRadius: CGFloat = AppTheme.panelRadius
    ) -> some View {
        AppPanel(padding: padding, cornerRadius: cornerRadius) {
            self
        }
    }

    func appKeyboardDismissable() -> some View {
        modifier(AppKeyboardDismissModifier())
    }
}

private struct AppKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.dismissAppKeyboard()
                    }
                }
            }
    }
}

extension UIApplication {
    func dismissAppKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
