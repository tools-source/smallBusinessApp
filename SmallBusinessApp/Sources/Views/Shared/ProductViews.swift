import SwiftUI

enum ContactSupport {
    static func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let filtered = trimmed.filter { $0.isNumber || $0 == "+" }
        return filtered.isEmpty ? nil : filtered
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

struct DashboardStatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var caption: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.weight(.bold))

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }
}

struct QuickActionLink: View {
    let title: String
    let systemImage: String
    let url: URL
    var tint: Color = .accentColor

    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(tint.opacity(0.14))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
