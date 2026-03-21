import PhotosUI
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingDeleteAccountAlert = false
    @State private var feedbackMessage = ""
    @State private var feedbackColor: Color = .red
    @State private var selectedProfilePhotoItem: PhotosPickerItem?
    @State private var fullNameDraft = ""
    @State private var publicEmailDraft = ""
    @State private var workerAddressDraft = ""
    @State private var workerPhoneDraft = ""
    @State private var businessNameDraft = ""
    @State private var businessAddressDraft = ""
    @State private var businessPhoneDraft = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                if let currentUser = store.currentUser {
                    profilePanel(for: currentUser)

                    if currentUser.role == .worker {
                        profilePhotoPanel(for: currentUser)
                    }

                    overviewPanel(for: currentUser)
                    ratingsPanel(for: currentUser)
                    applicationsPanel(for: currentUser)
                }

                workspacePanel
                sessionPanel
                dangerPanel

                if !feedbackMessage.isEmpty {
                    AppPanel {
                        Text(feedbackMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(feedbackColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 20)
        }
        .background(AppChromeBackground())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .appKeyboardDismissable()
        .onAppear {
            loadDrafts(from: store.currentUser)
        }
        .onChange(of: store.currentUser) { _, newValue in
            loadDrafts(from: newValue)
        }
        .onChange(of: selectedProfilePhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await updateProfilePhoto(from: newValue)
            }
        }
        .alert("Delete Account?", isPresented: $showingDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, posts, applications, and ratings.")
        }
    }

    private var receivedRatings: [UserRating] {
        guard let currentUser = store.currentUser else { return [] }
        return store.ratingsReceived(for: currentUser.id)
    }

    private var workspaceMessage: String {
        guard let currentUser = store.currentUser else { return "" }
        if currentUser.role == .business {
            if currentUser.businessProfileIsComplete {
                return "Use the Create tab to publish, edit, and remove job openings. Applications stay organized in their own tab."
            }
            return "Finish your business name, address, and phone here first. After that, the Create tab will let you publish openings."
        }
        if currentUser.workerProfileIsComplete {
            return "Use the Create tab to publish, edit, and remove your public worker profiles. Track every application in the applications tab."
        }
        return "Finish your phone number and address here first. After that, the Create tab will let you publish worker profiles."
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

    private func profilePanel(for currentUser: AppUser) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 18) {
                AppBadge(title: currentUser.role.title, systemImage: currentUser.role.icon, tint: AppTint.role(currentUser.role))

                HStack(alignment: .top, spacing: 14) {
                    UserAvatarView(
                        user: currentUser,
                        fallbackName: currentUser.displayName,
                        fallbackRole: currentUser.role,
                        size: 74
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentUser.displayName)
                            .font(.title3.weight(.bold))
                        Text(currentUser.emailDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Signed in with \(currentUser.authProvider.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                AppSectionHeader(
                    eyebrow: "Profile",
                    title: currentUser.role == .worker ? "Public identity" : "Business details",
                    subtitle: currentUser.role == .worker
                        ? "This information appears across your posts, ratings, and applications."
                        : "Keep your business details complete so you can publish openings and look credible to workers."
                )

                if currentUser.role == .worker {
                    fieldBlock(title: "Full Name") {
                        TextField("Full Name", text: $fullNameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .appFieldStyle()
                    }

                    fieldBlock(title: "Address") {
                        TextField("Street, city, state, zip", text: $workerAddressDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .appFieldStyle()
                    }

                    fieldBlock(title: "Phone Number") {
                        TextField("Phone Number", text: $workerPhoneDraft)
                            .keyboardType(.phonePad)
                            .appFieldStyle()
                    }
                } else {
                    fieldBlock(title: "Business Name") {
                        TextField("Business Name", text: $businessNameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .appFieldStyle()
                    }

                    fieldBlock(title: "Business Address") {
                        TextField("Business Address", text: $businessAddressDraft)
                            .textInputAutocapitalization(.words)
                            .appFieldStyle()
                    }

                    fieldBlock(title: "Business Phone") {
                        TextField("Business Phone", text: $businessPhoneDraft)
                            .keyboardType(.phonePad)
                            .appFieldStyle()
                    }
                }

                fieldBlock(title: currentUser.authProvider == .manual ? "Email" : "Public Email") {
                    TextField(currentUser.authProvider == .manual ? "Email" : "Public Email", text: $publicEmailDraft)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appFieldStyle()
                }

                if currentUser.authProvider == .apple && currentUser.hasHiddenAppleEmail {
                    Text("Apple may hide your real email address. Add a public email above so people in the app see your actual contact email instead of a relay address.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if currentUser.role == .worker {
                    VStack(alignment: .leading, spacing: 10) {
                        AppBadge(
                            title: currentUser.workerProfileIsComplete ? "Worker profile ready" : "Worker profile incomplete",
                            systemImage: currentUser.workerProfileIsComplete ? "checkmark.shield.fill" : "person.crop.circle.badge.exclamationmark",
                            tint: currentUser.workerProfileIsComplete ? .green : .orange
                        )

                        Label(currentUser.workerAddress ?? "Worker address missing", systemImage: "mappin.and.ellipse")
                        Label(currentUser.workerPhone ?? "Worker phone missing", systemImage: "phone.fill")

                        if !currentUser.workerProfileIsComplete {
                            Text("Add your address and phone number before publishing worker posts.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.subheadline)
                }

                if currentUser.role == .business {
                    VStack(alignment: .leading, spacing: 10) {
                        AppBadge(
                            title: currentUser.businessProfileIsComplete ? "Business ready" : "Profile incomplete",
                            systemImage: currentUser.businessProfileIsComplete ? "checkmark.shield.fill" : "building.2.crop.circle.badge.exclamationmark",
                            tint: currentUser.businessProfileIsComplete ? .green : .orange
                        )

                        Label(currentUser.businessName ?? "Business name missing", systemImage: "building.2")
                        Label(currentUser.businessAddress ?? "Business address missing", systemImage: "mappin.and.ellipse")
                        Label(currentUser.businessPhone ?? "Business phone missing", systemImage: "phone.fill")

                        if !currentUser.businessProfileIsComplete {
                            Text("Complete business name, address, and phone before publishing job openings.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.subheadline)
                }

                Button("Save Profile") {
                    saveProfile()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
    }

    private func profilePhotoPanel(for currentUser: AppUser) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: "Worker photo",
                    title: "Profile image",
                    subtitle: "Your photo appears on worker posts and job applications so businesses can recognize you."
                )

                ProfilePhotoPreviewView(
                    fileName: currentUser.profileImageFileName,
                    fallbackName: currentUser.displayName
                )

                PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                    Label(
                        currentUser.profileImageFileName == nil ? "Upload Profile Photo" : "Change Profile Photo",
                        systemImage: "photo.badge.plus"
                    )
                }
                .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))

                if currentUser.profileImageFileName != nil {
                    Button(role: .destructive) {
                        removeProfilePhoto()
                    } label: {
                        Label("Remove Profile Photo", systemImage: "trash")
                    }
                    .buttonStyle(AppSecondaryButtonStyle(tint: .red))
                }
            }
        }
    }

    private func overviewPanel(for currentUser: AppUser) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: "Overview",
                    title: "Account snapshot",
                    subtitle: "A quick read on trust, activity, and whether your profile is ready to operate."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        DashboardStatCard(
                            title: "Rating",
                            value: store.ratingSummary(for: currentUser.id).compactText,
                            systemImage: "star.fill",
                            caption: currentUser.role.ratingLabel,
                            tint: .accentColor
                        )
                        .frame(width: 180)

                        DashboardStatCard(
                            title: "Posts",
                            value: "\(store.myPosts.count)",
                            systemImage: rolePostIcon(for: currentUser.role),
                            caption: currentUser.role == .business ? "Openings or completed hiring records" : "Public worker profiles you've published",
                            tint: .orange
                        )
                        .frame(width: 180)

                        DashboardStatCard(
                            title: "Applications",
                            value: currentUser.role == .business ? "\(store.myReceivedApplications.count)" : "\(store.mySubmittedApplications.count)",
                            systemImage: currentUser.role == .business ? "tray.full.fill" : "paperplane.fill",
                            caption: currentUser.role == .business ? "Applications received by your business" : "Applications you have sent to businesses",
                            tint: .green
                        )
                        .frame(width: 180)

                        if currentUser.role == .worker {
                            DashboardStatCard(
                                title: "Profile Ready",
                                value: currentUser.workerProfileIsComplete ? "Ready" : "Needs Info",
                                systemImage: currentUser.workerProfileIsComplete ? "checkmark.circle.fill" : "person.crop.circle.badge.exclamationmark",
                                caption: currentUser.workerProfileIsComplete ? "Phone and address are filled in for posting" : "Add your phone number and address before posting worker profiles",
                                tint: currentUser.workerProfileIsComplete ? .green : .orange
                            )
                            .frame(width: 180)
                        } else {
                            DashboardStatCard(
                                title: "Business Ready",
                                value: currentUser.businessProfileIsComplete ? "Complete" : "Needs Info",
                                systemImage: currentUser.businessProfileIsComplete ? "checkmark.shield.fill" : "building.2.crop.circle.badge.exclamationmark",
                                caption: currentUser.businessProfileIsComplete ? "Your business account can publish openings" : "Add name, address, and phone before posting",
                                tint: currentUser.businessProfileIsComplete ? .green : .orange
                            )
                            .frame(width: 180)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func ratingsPanel(for currentUser: AppUser) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: "Rating",
                    title: currentUser.role.ratingLabel,
                    subtitle: store.ratingSummary(for: currentUser.id).detailText
                )

                if receivedRatings.isEmpty {
                    Text("No ratings yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(receivedRatings) { rating in
                        reviewRow(for: rating)
                    }
                }
            }
        }
    }

    private func applicationsPanel(for currentUser: AppUser) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionHeader(
                    eyebrow: "Applications",
                    title: currentUser.role == .business ? "Hiring activity" : "Your submissions",
                    subtitle: currentUser.role == .business
                        ? "\(store.myReceivedApplications.count) received across your business."
                        : "\(store.mySubmittedApplications.count) applications sent to businesses."
                )

                Label(
                    currentUser.role == .business ? "\(store.myReceivedApplications.count) received" : "\(store.mySubmittedApplications.count) sent",
                    systemImage: currentUser.role == .business ? "tray.full" : "paperplane"
                )
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var workspacePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: "Workspace",
                    title: "Jump to active areas",
                    subtitle: workspaceMessage
                )

                Button {
                    store.selectedTab = .create
                } label: {
                    Label("Manage Posts in Create Tab", systemImage: "square.and.pencil")
                }
                .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))

                Button {
                    store.selectedTab = .applications
                } label: {
                    Label(
                        store.currentUser?.role == .business ? "Open Business Applications" : "Open My Applications",
                        systemImage: "tray.full"
                    )
                }
                .buttonStyle(AppSecondaryButtonStyle(tint: .green))
            }
        }
    }

    private var sessionPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionHeader(
                    eyebrow: "Session",
                    title: "Sign out of this device",
                    subtitle: "Use this when you're done on a shared phone or want to switch accounts."
                )

                Button(role: .destructive) {
                    store.logout()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(AppSecondaryButtonStyle(tint: .red))
            }
        }
    }

    private var dangerPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionHeader(
                    eyebrow: "Danger Zone",
                    title: "Delete this account",
                    subtitle: "Deleting your account permanently removes your profile, posts, applications, and ratings."
                )

                Button(role: .destructive) {
                    showingDeleteAccountAlert = true
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                }
                .buttonStyle(AppSecondaryButtonStyle(tint: .red))
            }
        }
    }

    private func saveProfile() {
        do {
            try store.updateCurrentAccountProfile(
                fullName: fullNameDraft,
                publicEmail: publicEmailDraft,
                workerAddress: workerAddressDraft,
                workerPhone: workerPhoneDraft,
                businessName: businessNameDraft,
                businessAddress: businessAddressDraft,
                businessPhone: businessPhoneDraft
            )
            feedbackMessage = "Profile updated."
            feedbackColor = .green
        } catch {
            feedbackMessage = error.localizedDescription
            feedbackColor = .red
        }
    }

    private func loadDrafts(from user: AppUser?) {
        guard let user else { return }
        fullNameDraft = user.role == .worker ? user.fullName : ""
        publicEmailDraft = user.marketplaceEmail ?? ""
        workerAddressDraft = user.workerAddress ?? ""
        workerPhoneDraft = user.workerPhone ?? ""
        businessNameDraft = user.businessName ?? ""
        businessAddressDraft = user.businessAddress ?? ""
        businessPhoneDraft = user.businessPhone ?? ""
    }

    private func deleteAccount() {
        do {
            try store.deleteCurrentAccount()
            feedbackMessage = ""
        } catch {
            feedbackMessage = error.localizedDescription
            feedbackColor = .red
        }
    }

    private func removeProfilePhoto() {
        do {
            try store.removeCurrentWorkerProfilePhoto()
            feedbackMessage = "Profile photo removed."
            feedbackColor = .green
        } catch {
            feedbackMessage = error.localizedDescription
            feedbackColor = .red
        }
    }

    private func updateProfilePhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.invalidImageSelection
            }
            try store.updateCurrentWorkerProfilePhoto(with: data)
            feedbackMessage = "Profile photo updated."
            feedbackColor = .green
        } catch {
            feedbackMessage = error.localizedDescription
            feedbackColor = .red
        }
        selectedProfilePhotoItem = nil
    }

    private func rolePostIcon(for role: UserRole) -> String {
        role == .business ? "briefcase.fill" : "person.text.rectangle.fill"
    }

    private func reviewRow(for rating: UserRating) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= rating.score ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.caption)

            Text(rating.comment.isEmpty ? "No written comment." : rating.comment)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appPanelStyle(padding: 14, cornerRadius: 20)
    }
}
