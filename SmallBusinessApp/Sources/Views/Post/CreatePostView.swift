import SwiftUI
import UIKit

private enum PostFormField: Hashable {
    case title
    case location
    case payOrRate
    case schedule
    case contact
    case details
}

struct CreatePostView: View {
    @EnvironmentObject private var store: AppStore

    @State private var category: BusinessCategory = .grocery
    @State private var title = ""
    @State private var details = ""
    @State private var location = ""
    @State private var payOrRate = ""
    @State private var schedule = ""
    @State private var contact = ""
    @State private var feedbackMessage = ""
    @State private var editingPostID: UUID?
    @FocusState private var focusedField: PostFormField?

    private var role: UserRole {
        store.currentUser?.role ?? .business
    }

    private var isEditing: Bool {
        editingPostID != nil
    }

    private var businessProfileIsComplete: Bool {
        store.currentUser?.businessProfileIsComplete ?? false
    }

    private var canUsePostingForm: Bool {
        role != .business || businessProfileIsComplete
    }

    var body: some View {
        Form {
            Section(role == .business ? "Manage Job Openings" : "Manage Worker Profiles") {
                if store.myPosts.isEmpty {
                    Text(role == .business
                         ? "Your published job openings will appear here."
                         : "Your published worker profiles will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.myPosts) { post in
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(post.title)
                                        .font(.headline)
                                    Spacer()
                                    if editingPostID == post.id {
                                        Text("Editing")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.14))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text("\(post.postType.title) • \(post.category.title) • \(post.location)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Button("Edit") {
                                    startEditing(post)
                                }
                                .buttonStyle(.bordered)
                                .disabled(role == .business && !businessProfileIsComplete)

                                Button("Delete", role: .destructive) {
                                    delete(post)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Account Type") {
                Label(role.title, systemImage: role.icon)
                Label(role.allowedPostType.title, systemImage: role.allowedPostType.icon)
            }

            if role == .business && !businessProfileIsComplete {
                Section("Complete Business Profile") {
                    Text("Add your business name, address, and phone number in the Account tab before publishing job openings.")
                        .foregroundStyle(.secondary)

                    Button {
                        store.selectedTab = .account
                    } label: {
                        Label("Open Account Setup", systemImage: "person.crop.circle")
                    }
                }
            } else {
                Section("Business Category") {
                    Picker("Category", selection: $category) {
                        ForEach(BusinessCategory.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }

                Section("Main Info") {
                    TextField(titlePlaceholder, text: $title)
                        .focused($focusedField, equals: .title)
                    TextField("Location", text: $location)
                        .focused($focusedField, equals: .location)
                    TextField(payPlaceholder, text: $payOrRate)
                        .focused($focusedField, equals: .payOrRate)
                    TextField(schedulePlaceholder, text: $schedule)
                        .focused($focusedField, equals: .schedule)
                    TextField("Contact (email or phone)", text: $contact)
                        .focused($focusedField, equals: .contact)
                }

                Section(role == .business ? "Job Description" : "Worker Summary") {
                    TextEditor(text: $details)
                        .frame(minHeight: 140)
                        .focused($focusedField, equals: .details)
                    Text(detailsHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Text(primaryActionTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if isEditing {
                        Button(role: .cancel) {
                            cancelEditing()
                        } label: {
                            Text("Cancel Editing")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !feedbackMessage.isEmpty {
                Section {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(feedbackColor)
                }
            }
        }
        .navigationTitle(isEditing
                         ? (role == .business ? "Edit Opening" : "Edit Profile")
                         : (role == .business ? "Post Opening" : "Post Profile"))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
        .onAppear {
            contact = contact.isEmpty ? (store.currentUser?.marketplaceEmail ?? store.currentUser?.email ?? "") : contact
        }
    }

    private var titlePlaceholder: String {
        switch role {
        case .business:
            return "Job Title / Hiring Headline"
        case .worker:
            return "Worker Headline / Experience Summary"
        }
    }

    private var payPlaceholder: String {
        switch role {
        case .business:
            return "Pay / Salary / Rate (optional)"
        case .worker:
            return "Expected Pay / Rate (optional)"
        }
    }

    private var schedulePlaceholder: String {
        switch role {
        case .business:
            return "Schedule Needed (optional)"
        case .worker:
            return "Availability (optional)"
        }
    }

    private var detailsHint: String {
        switch role {
        case .business:
            return "Describe the job, duties, ideal experience, and any language or shift needs."
        case .worker:
            return "Describe your experience, strengths, languages, and the type of work you're seeking."
        }
    }

    private var successMessage: String {
        role == .business ? "Job opening published successfully." : "Worker profile published successfully."
    }

    private var updateSuccessMessage: String {
        role == .business ? "Job opening updated." : "Worker profile updated."
    }

    private var primaryActionTitle: String {
        isEditing
            ? (role == .business ? "Save Job Opening" : "Save Worker Profile")
            : role.createButtonTitle
    }

    private var feedbackColor: Color {
        let validSuccessMessages = [successMessage, updateSuccessMessage]
        return validSuccessMessages.contains(feedbackMessage) ? .green : .red
    }

    private func submit() {
        dismissKeyboard()
        do {
            if let editingPostID {
                try store.updatePost(
                    postID: editingPostID,
                    category: category,
                    title: title,
                    details: details,
                    location: location,
                    payOrRate: payOrRate,
                    schedule: schedule,
                    contact: contact
                )
                feedbackMessage = updateSuccessMessage
            } else {
                try store.createPost(
                    postType: role.allowedPostType,
                    category: category,
                    title: title,
                    details: details,
                    location: location,
                    payOrRate: payOrRate,
                    schedule: schedule,
                    contact: contact
                )
                feedbackMessage = successMessage
            }
            resetForm()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func startEditing(_ post: JobPost) {
        editingPostID = post.id
        category = post.category
        title = post.title
        details = post.details
        location = post.location
        payOrRate = post.payOrRate
        schedule = post.schedule
        contact = post.authorContact
        feedbackMessage = ""
        focusedField = .title
    }

    private func cancelEditing() {
        feedbackMessage = ""
        resetForm()
        dismissKeyboard()
    }

    private func delete(_ post: JobPost) {
        store.deletePost(post)
        if editingPostID == post.id {
            cancelEditing()
        } else {
            feedbackMessage = ""
        }
    }

    private func resetForm() {
        category = .grocery
        title = ""
        details = ""
        location = ""
        payOrRate = ""
        schedule = ""
        contact = store.currentUser?.marketplaceEmail ?? store.currentUser?.email ?? ""
        editingPostID = nil
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
