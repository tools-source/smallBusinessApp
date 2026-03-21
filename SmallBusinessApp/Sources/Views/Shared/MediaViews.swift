import SwiftUI
import UIKit

struct StoredMediaImageView<Placeholder: View>: View {
    @EnvironmentObject private var store: AppStore

    let fileName: String?
    let contentMode: ContentMode
    let placeholder: Placeholder

    @State private var uiImage: UIImage?

    init(
        fileName: String?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.fileName = fileName
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: fileName) {
            loadImage()
        }
    }

    private func loadImage() {
        guard let data = store.imageData(fileName: fileName),
              let image = UIImage(data: data) else {
            uiImage = nil
            return
        }
        uiImage = image
    }
}

struct UserAvatarView: View {
    let user: AppUser?
    let fallbackName: String
    let fallbackRole: UserRole
    var explicitFileName: String? = nil
    var size: CGFloat = 56

    var body: some View {
        StoredMediaImageView(fileName: imageFileName) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .overlay {
                    if fallbackRole == .worker {
                        Text(initials)
                            .font(.system(size: size * 0.32, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: fallbackRole.icon)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1)
        }
    }

    private var imageFileName: String? {
        guard fallbackRole == .worker else { return nil }
        return explicitFileName ?? user?.profileImageFileName
    }

    private var initials: String {
        let words = fallbackName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }

        let value = String(words).uppercased()
        return value.isEmpty ? "W" : value
    }
}

struct DocumentPreviewView: View {
    let fileName: String?

    var body: some View {
        StoredMediaImageView(fileName: fileName, contentMode: .fit) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    Label("ID Image Not Available", systemImage: "doc.text.image")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180, maxHeight: 240)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ProfilePhotoPreviewView: View {
    let fileName: String?
    let fallbackName: String

    var body: some View {
        StoredMediaImageView(fileName: fileName, contentMode: .fit) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.square")
                            .font(.system(size: 34, weight: .semibold))
                        Text("No Profile Photo Submitted")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180, maxHeight: 240)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(fallbackName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .padding(12)
        }
    }
}
