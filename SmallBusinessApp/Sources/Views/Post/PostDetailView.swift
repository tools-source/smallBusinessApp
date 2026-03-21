import PhotosUI
import SwiftUI
import UIKit

struct PostDetailView: View {
    @EnvironmentObject private var store: AppStore

    let post: JobPost

    @State private var ratingFeedbackMessage = ""
    @State private var selectedRating = 0
    @State private var ratingComment = ""
    @State private var applicationFeedbackMessage = ""
    @State private var applicationMessage = ""
    @State private var applicationContact = ""
    @State private var selectedIDPhotoItem: PhotosPickerItem?
    @State private var selectedIDImageData: Data?

    private var resolvedPost: JobPost {
        store.post(for: post.id) ?? post
    }

    private var authorRole: UserRole {
        store.user(for: resolvedPost.authorID)?.role ?? resolvedPost.authorRole
    }

    private var author: AppUser? {
        store.user(for: resolvedPost.authorID)
    }

    private var currentApplication: JobApplication? {
        store.currentUserApplication(for: resolvedPost.id)
    }

    private var isCurrentUsersHiringPost: Bool {
        guard let currentUser = store.currentUser else { return false }
        return currentUser.id == resolvedPost.authorID && resolvedPost.postType == .employerHiring
    }

    private var authorEmailText: String? {
        ContactSupport.emailCandidate(
            primary: author?.marketplaceEmail ?? resolvedPost.authorContact,
            fallback: author?.email
        )
    }

    private var authorPhoneText: String? {
        ContactSupport.phoneCandidate(
            primary: author?.preferredPhone ?? resolvedPost.authorContact
        )
    }

    private var authorEmailURL: URL? {
        ContactSupport.emailURL(primary: authorEmailText, fallback: author?.email)
    }

    private var authorPhoneURL: URL? {
        ContactSupport.phoneURL(authorPhoneText)
    }

    private var canShowQuickActions: Bool {
        guard store.currentUser?.id != resolvedPost.authorID else { return false }
        return authorEmailURL != nil || authorPhoneURL != nil
    }

    private var authorReviews: [UserRating] {
        store.ratingsReceived(for: resolvedPost.authorID)
    }

    private var existingRating: UserRating? {
        store.currentUserRatingEntry(for: resolvedPost.authorID)
    }

    private var trimmedRatingComment: String {
        ratingComment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section("Summary") {
                if authorRole == .worker {
                    HStack(spacing: 14) {
                        UserAvatarView(
                            user: author,
                            fallbackName: resolvedPost.authorName,
                            fallbackRole: authorRole,
                            size: 64
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(resolvedPost.authorName)
                                .font(.headline)
                            Text(authorRole.ratingLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                detailRow(icon: resolvedPost.postType.icon, title: resolvedPost.postType.title)
                detailRow(icon: authorRole.icon, title: authorRole.title)
                detailRow(icon: "star.leadinghalf.filled", title: "\(authorRole.ratingLabel): \(store.ratingSummary(for: resolvedPost.authorID).detailText)")
                detailRow(icon: "tag", title: resolvedPost.category.title)
                detailRow(icon: "person", title: resolvedPost.authorName)
                if let authorEmailText {
                    detailRow(icon: "envelope", title: authorEmailText)
                }
                if let authorPhoneText {
                    detailRow(icon: "phone", title: authorPhoneText)
                }
                detailRow(icon: "mappin.and.ellipse", title: resolvedPost.location)
                if resolvedPost.postType == .employerHiring && !resolvedPost.isActive {
                    detailRow(icon: "checkmark.seal.fill", title: "Position filled")
                }
                if let payDisplay = CompensationSupport.formattedDisplay(resolvedPost.payOrRate) {
                    detailRow(icon: "dollarsign.circle", title: payDisplay)
                }
                if !resolvedPost.schedule.isEmpty {
                    detailRow(icon: "calendar", title: resolvedPost.schedule)
                }
                detailRow(icon: "clock", title: resolvedPost.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if canShowQuickActions {
                Section("Quick Actions") {
                    HStack(spacing: 10) {
                        if let authorEmailURL {
                            QuickActionLink(
                                title: "Email",
                                systemImage: "envelope.fill",
                                url: authorEmailURL
                            )
                        }
                        if let authorPhoneURL {
                            QuickActionLink(
                                title: "Call",
                                systemImage: "phone.fill",
                                url: authorPhoneURL,
                                tint: .green
                            )
                        }
                    }
                }
            }

            Section("Title") {
                Text(resolvedPost.title)
            }

                Section("Details") {
                    Text(resolvedPost.details)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !authorReviews.isEmpty {
                    Section(authorRole == .business ? "Business Reviews" : "Worker Reviews") {
                        ForEach(authorReviews) { review in
                            reviewRow(for: review)
                        }
                    }
                }

                if let application = currentApplication {
                    Section("Your Application") {
                    detailRow(icon: application.status.systemImage, title: "Status: \(application.status.title)")
                    detailRow(icon: "phone", title: application.workerContact)
                    detailRow(icon: "checkmark.shield", title: application.workerIDImageFileName == nil ? "ID image missing" : "Government ID submitted")
                    detailRow(icon: "clock", title: application.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text(application.message)
                        .fixedSize(horizontal: false, vertical: true)

                    if let workerIDImageFileName = application.workerIDImageFileName {
                        DocumentPreviewView(fileName: workerIDImageFileName)
                    }
                }
            } else if store.canCurrentUserApply(to: resolvedPost) {
                Section("Apply for This Job") {
                    applicationComposerCard
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            if isCurrentUsersHiringPost {
                Section("Applications") {
                    NavigationLink {
                        ApplicationsView(initialPostID: resolvedPost.id)
                    } label: {
                        Label("\(store.applicationCount(for: resolvedPost.id)) applications received", systemImage: "tray.full")
                    }

                    Text("Open the applications inbox to review workers and update their status.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if store.canCurrentUserRate(targetUserID: resolvedPost.authorID, targetRole: authorRole) {
                Section("Rate \(resolvedPost.authorName)") {
                    reviewComposerCard

                    if !ratingFeedbackMessage.isEmpty {
                        Text(ratingFeedbackMessage)
                            .font(.footnote)
                            .foregroundStyle(ratingFeedbackMessage == "Rating saved." ? .green : .red)
                    }
                }
            }

            if !applicationFeedbackMessage.isEmpty {
                Section {
                    Text(applicationFeedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(applicationFeedbackMessage == "Application sent." ? .green : .red)
                }
            }
        }
        .navigationTitle("Post Details")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppChromeBackground())
        .appKeyboardDismissable()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onChange(of: selectedIDPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadWorkerIDImage(from: newValue)
            }
        }
        .onAppear {
            if applicationContact.isEmpty {
                applicationContact = store.currentUser?.preferredPhone
                    ?? store.currentUser?.marketplaceEmail
                    ?? store.currentUser?.email
                    ?? ""
            }
            if let currentRating = existingRating {
                selectedRating = currentRating.score
                if ratingComment.isEmpty {
                    ratingComment = currentRating.comment
                }
            }
        }
    }

    private func submitRating() {
        UIApplication.shared.dismissAppKeyboard()
        do {
            try store.submitRating(score: selectedRating, comment: ratingComment, for: resolvedPost.authorID)
            ratingFeedbackMessage = "Rating saved."
        } catch {
            ratingFeedbackMessage = error.localizedDescription
        }
    }

    private func submitApplication() {
        UIApplication.shared.dismissAppKeyboard()
        do {
            try store.applyToPost(
                post: resolvedPost,
                message: applicationMessage,
                contact: applicationContact,
                workerIDImageData: selectedIDImageData
            )
            applicationFeedbackMessage = "Application sent."
            applicationMessage = ""
            selectedIDImageData = nil
        } catch {
            applicationFeedbackMessage = error.localizedDescription
        }
    }

    private func loadWorkerIDImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.invalidImageSelection
            }
            selectedIDImageData = data
            applicationFeedbackMessage = ""
        } catch {
            applicationFeedbackMessage = error.localizedDescription
        }
        selectedIDPhotoItem = nil
    }

    private func detailRow(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
    }

    private var applicationComposerCard: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    AppBadge(title: "Worker application", systemImage: "paperplane.fill", tint: .accentColor)

                    Text("Send a clear intro and a reliable contact")
                        .font(.headline)

                    Text("Businesses review your message, your best contact info, and a government ID photo together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .opacity(0.45)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Best contact info")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)

                        TextField("Phone or email the business should use", text: $applicationContact)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .appFieldStyle()
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Short introduction")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Required" : "Ready")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green)
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            }

                        TextEditor(text: $applicationMessage)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)

                        if applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Introduce yourself, mention relevant experience, and say why this role fits you.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Government ID")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        AppBadge(
                            title: selectedIDImageData == nil ? "Required" : "Attached",
                            systemImage: selectedIDImageData == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                            tint: selectedIDImageData == nil ? .orange : .green
                        )
                    }

                    PhotosPicker(selection: $selectedIDPhotoItem, matching: .images) {
                        Label(
                            selectedIDImageData == nil ? "Upload Government ID" : "Change Government ID",
                            systemImage: "person.text.rectangle"
                        )
                    }
                    .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))

                    if let selectedIDImageData,
                       let previewImage = UIImage(data: selectedIDImageData) {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 180, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("A government ID photo is required for every application.", systemImage: "checkmark.shield")
                                .font(.footnote.weight(.semibold))
                            Text("Use a clear photo so the business can review your submission quickly.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appFieldStyle(verticalPadding: 16)
                    }
                }

                Button("Send Application") {
                    submitApplication()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canSubmitApplication)
                .opacity(canSubmitApplication ? 1 : 0.65)
            }
        }
    }

    private var shareText: String {
        [
            resolvedPost.title,
            resolvedPost.location,
            resolvedPost.authorName,
            "Shared from HireLocal"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    private var canSubmitApplication: Bool {
        !applicationContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedIDImageData != nil
    }

    private var reviewComposerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Share your experience")
                        .font(.headline)
                    Text("Comment on reliability, communication, professionalism, and overall fit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedRating > 0 {
                    Text(ratingBadgeText(for: selectedRating))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ratingBadgeColor(for: selectedRating).opacity(0.14))
                        .foregroundStyle(ratingBadgeColor(for: selectedRating))
                        .clipShape(Capsule())
                }
            }

            if let existingRating {
                Label("Editing your existing \(existingRating.score)-star review", systemImage: "pencil.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Rating")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { score in
                        ratingButton(score: score)
                    }
                }

                if selectedRating > 0 {
                    Text("\(selectedRating)/5 selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Comment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if trimmedRatingComment.isEmpty {
                        Text("Required")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))

                    TextEditor(text: $ratingComment)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 138)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)

                    if trimmedRatingComment.isEmpty {
                        Text("Write a useful review so others understand what it was like working together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }

                Text("Strong reviews are specific and brief.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                submitRating()
            } label: {
                Text(existingRating == nil ? "Save Review" : "Update Review")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private func ratingButton(score: Int) -> some View {
        let isFilled = selectedRating >= score
        let isSelected = selectedRating == score

        return Button {
            selectedRating = score
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isFilled ? "star.fill" : "star")
                    .font(.title3)
                Text("\(score)")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isFilled ? .yellow : .secondary)
            .background(isSelected ? Color.yellow.opacity(0.14) : Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.yellow.opacity(0.5) : Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func ratingBadgeText(for score: Int) -> String {
        switch score {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        case 5: return "Excellent"
        default: return "New"
        }
    }

    private func ratingBadgeColor(for score: Int) -> Color {
        switch score {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .blue
        case 5: return .green
        default: return .secondary
        }
    }

    private func reviewRow(for rating: UserRating) -> some View {
        HStack(alignment: .top, spacing: 12) {
            UserAvatarView(
                user: store.user(for: rating.raterUserID),
                fallbackName: store.user(for: rating.raterUserID)?.displayName ?? "Anonymous",
                fallbackRole: store.user(for: rating.raterUserID)?.role ?? .worker,
                size: 44
            )

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.user(for: rating.raterUserID)?.displayName ?? "Anonymous")
                                .font(.subheadline.weight(.semibold))
                            Text(store.user(for: rating.raterUserID)?.role.title ?? "Reviewer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rating.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { value in
                                Image(systemName: value <= rating.score ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .font(.caption)

                        Text("\(rating.score)/5")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(rating.comment)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .padding(.vertical, 4)
    }
}
