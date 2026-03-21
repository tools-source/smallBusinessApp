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
    @State private var businessNameDraft = ""
    @State private var businessAddressDraft = ""
    @State private var businessPhoneDraft = ""

    var body: some View {
        List {
            if let currentUser = store.currentUser {
                Section("Profile") {
                    HStack(spacing: 14) {
                        UserAvatarView(
                            user: currentUser,
                            fallbackName: currentUser.displayName,
                            fallbackRole: currentUser.role,
                            size: 72
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(currentUser.displayName)
                                .font(.headline)
                            Text(currentUser.emailDisplayText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(currentUser.role.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    if currentUser.role == .worker {
                        TextField("Full Name", text: $fullNameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    } else {
                        TextField("Business Name", text: $businessNameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        TextField("Business Address", text: $businessAddressDraft)
                            .textInputAutocapitalization(.words)
                        TextField("Business Phone", text: $businessPhoneDraft)
                            .keyboardType(.phonePad)
                    }

                    TextField(currentUser.authProvider == .manual ? "Email" : "Public Email", text: $publicEmailDraft)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Save Profile") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)

                    if currentUser.authProvider == .apple && currentUser.hasHiddenAppleEmail {
                        Text("Apple may hide your real email address. Add a public email above so people in the app see your actual contact email instead of a relay address.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if currentUser.role == .business {
                        Label(currentUser.businessName ?? "Business name missing", systemImage: "building.2")
                        Label(currentUser.businessAddress ?? "Business address missing", systemImage: "mappin.and.ellipse")
                        Label(currentUser.businessPhone ?? "Business phone missing", systemImage: "phone.fill")

                        if !currentUser.businessProfileIsComplete {
                            Text("Complete business name, address, and phone before publishing job openings.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }

                    Label(currentUser.emailDisplayText, systemImage: "envelope.fill")
                    Label(currentUser.role.title, systemImage: "person.text.rectangle")
                    Label("Signed in with \(currentUser.authProvider.displayName)", systemImage: "key.fill")
                }

                if currentUser.role == .worker {
                    Section("Worker Profile Photo") {
                        PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                            Label(
                                currentUser.profileImageFileName == nil ? "Upload Profile Photo" : "Change Profile Photo",
                                systemImage: "photo.badge.plus"
                            )
                        }

                        if currentUser.profileImageFileName != nil {
                            Button(role: .destructive) {
                                removeProfilePhoto()
                            } label: {
                                Label("Remove Profile Photo", systemImage: "trash")
                            }
                        }

                        Text("Your worker photo appears on your worker posts and on job applications you send.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Overview") {
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
                                    value: currentUser.profileImageFileName == nil ? "Needs Photo" : "Complete",
                                    systemImage: currentUser.profileImageFileName == nil ? "person.crop.circle.badge.exclamationmark" : "checkmark.circle.fill",
                                    caption: currentUser.profileImageFileName == nil ? "Add a profile photo to look more credible to businesses" : "Your photo appears on posts and applications",
                                    tint: currentUser.profileImageFileName == nil ? .orange : .green
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

                Section("Rating") {
                    Label(currentUser.role.ratingLabel, systemImage: "star.fill")
                    Text(store.ratingSummary(for: currentUser.id).detailText)
                        .foregroundStyle(.secondary)

                    if receivedRatings.isEmpty {
                        Text("No ratings yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(receivedRatings) { rating in
                            reviewRow(for: rating)
                        }
                    }
                }

                Section("Applications") {
                    if currentUser.role == .business {
                        Label("\(store.myReceivedApplications.count) received", systemImage: "tray.full")
                    } else {
                        Label("\(store.mySubmittedApplications.count) sent", systemImage: "paperplane")
                    }
                }
            }

            Section("Workspace") {
                Button {
                    store.selectedTab = .create
                } label: {
                    Label("Manage Posts in Create Tab", systemImage: "square.and.pencil")
                }

                Button {
                    store.selectedTab = .applications
                } label: {
                    Label(
                        store.currentUser?.role == .business ? "Open Business Applications" : "Open My Applications",
                        systemImage: "tray.full"
                    )
                }

                Text(workspaceMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    store.logout()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAccountAlert = true
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                }

                Text("Deleting your account permanently removes your profile, posts, applications, and ratings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !feedbackMessage.isEmpty {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(feedbackColor)
                }
            }
        }
        .navigationTitle("Account")
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
        return "Use the Create tab to publish, edit, and remove your public worker profiles. Track every application in the applications tab."
    }

    private func saveProfile() {
        do {
            try store.updateCurrentAccountProfile(
                fullName: fullNameDraft,
                publicEmail: publicEmailDraft,
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
        .padding(.vertical, 6)
    }
}
