import SwiftUI

enum ContactSupport {
    static func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("@") else { return nil }

        let digitCount = trimmed.filter(\.isNumber).count
        guard digitCount >= 7 else { return nil }

        let digits = trimmed.filter(\.isNumber)
        let normalizedDigits = trimmed.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
            ? "+\(digits)"
            : digits
        return normalizedDigits.isEmpty ? nil : normalizedDigits
    }

    static func emailCandidate(primary: String?, fallback: String? = nil) -> String? {
        for candidate in [primary, fallback] {
            guard let candidate else { continue }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("@") {
                return trimmed
            }
        }
        return nil
    }

    static func phoneCandidate(primary: String?) -> String? {
        normalizedPhone(primary)
    }

    static func emailURL(primary: String?, fallback: String? = nil) -> URL? {
        guard let email = emailCandidate(primary: primary, fallback: fallback),
              let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "mailto:\(encoded)")
    }

    static func phoneURL(_ value: String?) -> URL? {
        guard let phone = phoneCandidate(primary: value) else { return nil }
        return URL(string: "tel:\(phone)")
    }
}

enum CompensationSupport {
    static func formattedDisplay(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("$") else { return trimmed }

        if let firstCharacter = trimmed.first,
           firstCharacter.isNumber || firstCharacter == "." {
            return "$\(trimmed)"
        }

        return trimmed
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var caption: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppBadge(title: title, systemImage: systemImage, tint: tint)

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()

            Spacer(minLength: 0)

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .appPanelStyle(padding: 16, cornerRadius: 22)
    }
}

struct QuickActionLink: View {
    let title: String
    let systemImage: String
    let url: URL
    var tint: Color = .accentColor

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
