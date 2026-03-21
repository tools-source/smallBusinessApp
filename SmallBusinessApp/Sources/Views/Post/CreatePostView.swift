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
    @EnvironmentObject private var locationManager: AppLocationManager

    @State private var category: BusinessCategory = .grocery
    @State private var title = ""
    @State private var details = ""
    @State private var location = ""
    @State private var payOrRate = ""
    @State private var schedule = ""
    @State private var contact = ""
    @State private var feedbackMessage = ""
    @State private var editingPostID: UUID?
    @State private var showingSchedulePicker = false
    @State private var scheduleUsesTimeRange = false
    @State private var scheduleStartTime = CreatePostView.defaultStartTime
    @State private var scheduleEndTime = CreatePostView.defaultEndTime
    @State private var draftScheduleStartTime = CreatePostView.defaultStartTime
    @State private var draftScheduleEndTime = CreatePostView.defaultEndTime
    @State private var legacyScheduleText: String?
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

    private var workerProfileIsComplete: Bool {
        store.currentUser?.workerProfileIsComplete ?? false
    }

    private var canUsePostingForm: Bool {
        store.currentUser?.postingProfileIsComplete ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                managePostsPanel
                accountTypePanel

                if !canUsePostingForm {
                    completeProfilePanel
                } else {
                    postDetailsPanel
                    actionsPanel
                }

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
        .navigationTitle(isEditing
                         ? (role == .business ? "Edit Opening" : "Edit Profile")
                         : (role == .business ? "Post Opening" : "Post Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .appKeyboardDismissable()
        .sheet(isPresented: $showingSchedulePicker) {
            schedulePickerSheet
                .presentationDetents([.height(560)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            contact = contact.isEmpty ? (store.currentUser?.marketplaceEmail ?? store.currentUser?.email ?? "") : contact
            syncScheduleState(from: schedule)
            locationManager.refreshLocation()
        }
    }

    private var managePostsPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppBadge(
                    title: role == .business ? "Business publisher" : "Worker publisher",
                    systemImage: role.icon,
                    tint: AppTint.role(role)
                )

                AppSectionHeader(
                    eyebrow: role == .business ? "Job openings" : "Worker profiles",
                    title: role == .business ? "Manage published openings" : "Manage published profiles",
                    subtitle: role == .business
                        ? "Edit active listings or remove old hiring posts."
                        : "Keep your public worker profile current and easy to understand."
                )

                if store.myPosts.isEmpty {
                    Text(role == .business
                         ? "Your published job openings will appear here."
                         : "Your published worker profiles will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.myPosts) { post in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(post.title)
                                        .font(.headline)

                                    Text("\(post.postType.title) • \(post.category.title) • \(post.location)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if editingPostID == post.id {
                                    AppBadge(title: "Editing", systemImage: "pencil", tint: .accentColor)
                                }
                            }

                            HStack(spacing: 10) {
                                Button("Edit") {
                                    startEditing(post)
                                }
                                .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))
                                .disabled(!canUsePostingForm)

                                Button(role: .destructive) {
                                    delete(post)
                                } label: {
                                    Text("Delete")
                                }
                                .buttonStyle(AppSecondaryButtonStyle(tint: .red))
                            }
                        }
                        .padding(.vertical, 4)

                        if post.id != store.myPosts.last?.id {
                            Divider()
                                .opacity(0.45)
                        }
                    }
                }
            }
        }
    }

    private var accountTypePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    eyebrow: "Account type",
                    title: role.title,
                    subtitle: "This account can publish \(role.allowedPostType.title.lowercased()) posts."
                )

                HStack(spacing: 10) {
                    AppBadge(title: role.title, systemImage: role.icon, tint: AppTint.role(role))
                    AppBadge(title: role.allowedPostType.title, systemImage: role.allowedPostType.icon, tint: AppTint.postType(role.allowedPostType))
                }
            }
        }
    }

    private var completeProfilePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    eyebrow: "Complete profile",
                    title: role == .business ? "Business details required" : "Worker details required",
                    subtitle: role == .business
                        ? "Add your business name, address, and phone number in the Account tab before publishing job openings."
                        : "Add your phone number and address in the Account tab before publishing worker posts."
                )

                Button {
                    store.selectedTab = .account
                } label: {
                    Label("Open Account Setup", systemImage: "person.crop.circle")
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
    }

    private var postDetailsPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: role == .business ? "Opening details" : "Profile details",
                    title: isEditing ? "Update your post" : "Create a new post",
                    subtitle: role == .business
                        ? "Keep the title concrete, location clear, and the description specific enough for workers to act on."
                        : "Make your headline, availability, and experience easy for businesses to scan."
                )

                fieldBlock(title: "Business Category") {
                    categoryMenu
                }

                fieldBlock(title: role == .business ? "Job Title" : "Worker Headline") {
                    TextField(titlePlaceholder, text: $title)
                        .focused($focusedField, equals: .title)
                        .appFieldStyle()
                }

                fieldBlock(title: "Location") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Location", text: $location)
                            .focused($focusedField, equals: .location)
                            .appFieldStyle()

                        if let currentAddress = locationManager.currentAddress {
                            Button {
                                location = currentAddress
                            } label: {
                                Label("Use Current Location", systemImage: "location.fill")
                            }
                            .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))
                        } else {
                            Button {
                                locationManager.refreshLocation()
                            } label: {
                                Label("Enable Live Location", systemImage: "location.circle")
                            }
                            .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))
                        }
                    }
                }

                fieldBlock(title: role == .business ? "Pay / Salary / Rate" : "Expected Pay / Rate") {
                    HStack(spacing: 10) {
                        Text("$")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(payPlaceholder, text: payBinding)
                            .focused($focusedField, equals: .payOrRate)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    .appFieldStyle()
                }

                fieldBlock(title: role == .business ? "Schedule Needed" : "Availability") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                openSchedulePicker()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scheduleSummaryTitle)
                                            .foregroundStyle(scheduleDisplayText == nil ? .secondary : .primary)

                                        Text(hasScheduleValue ? "Tap to edit time range" : "Tap to choose from and to time")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .appFieldStyle()
                            }
                            .buttonStyle(.plain)

                            if hasScheduleValue {
                                Button("Clear") {
                                    clearSchedule()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                            }
                        }

                        if let legacyScheduleText, !scheduleUsesTimeRange {
                            Text("Current saved schedule: \(legacyScheduleText). Opening the picker will replace it with a From/To time range.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                fieldBlock(title: "Contact") {
                    TextField("Contact (email or phone)", text: $contact)
                        .focused($focusedField, equals: .contact)
                        .appFieldStyle()
                }

                fieldBlock(title: role == .business ? "Job Description" : "Worker Summary") {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            }

                        TextEditor(text: $details)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .focused($focusedField, equals: .details)

                        if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(detailsHint)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private var actionsPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    eyebrow: "Actions",
                    title: primaryActionTitle,
                    subtitle: isEditing ? "Save changes to update the existing post." : "Publish when the details are ready."
                )

                Button {
                    submit()
                } label: {
                    Text(primaryActionTitle)
                }
                .buttonStyle(AppPrimaryButtonStyle())

                if isEditing {
                    Button(role: .cancel) {
                        cancelEditing()
                    } label: {
                        Text("Cancel Editing")
                    }
                    .buttonStyle(AppSecondaryButtonStyle(tint: .accentColor))
                }
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(BusinessCategory.allCases) { value in
                Button(value.title) {
                    category = value
                }
            }
        } label: {
            HStack {
                Text(category.title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .appFieldStyle()
        }
        .buttonStyle(.plain)
    }

    private func timeWheel(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipped()
            .appFieldStyle(verticalPadding: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var schedulePickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button("Cancel") {
                    showingSchedulePicker = false
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("Schedule")
                    .font(.headline.weight(.bold))

                Spacer()

                Color.clear
                    .frame(width: 64, height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose From and To")
                            .font(.title3.weight(.bold))
                        Text("Pick the start and end time without expanding the full post form.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let legacyScheduleText, !scheduleUsesTimeRange {
                        Text("Applying these hours will replace the saved schedule: \(legacyScheduleText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appFieldStyle(verticalPadding: 14)
                    }

                    VStack(spacing: 14) {
                        timeWheel(title: "From", selection: draftStartTimeBinding)
                        timeWheel(title: "To", selection: draftEndTimeBinding)
                    }

                    Text("Scroll each wheel to choose the start and end time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                if hasScheduleValue {
                    Button("Remove Schedule") {
                        clearSchedule()
                        showingSchedulePicker = false
                    }
                    .buttonStyle(AppSecondaryButtonStyle(tint: .red))
                }

                Button("Apply Hours") {
                    applyDraftSchedule()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [
                    Color("BrandBackground").opacity(0.98),
                    AppTheme.ink.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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

    private var titlePlaceholder: String {
        switch role {
        case .business:
            return "Job Title / Hiring Headline"
        case .worker:
            return "Worker Headline / Experience Summary"
        }
    }

    private var payPlaceholder: String {
        "20 / hour or 800 / week"
    }

    private var schedulePlaceholder: String {
        switch role {
        case .business:
            return "Schedule Needed (optional)"
        case .worker:
            return "Availability (optional)"
        }
    }

    private var scheduleSummaryTitle: String {
        scheduleDisplayText ?? schedulePlaceholder
    }

    private var scheduleDisplayText: String? {
        if scheduleUsesTimeRange {
            return formattedSchedule(from: scheduleStartTime, to: scheduleEndTime)
        }

        guard let legacyScheduleText,
              !legacyScheduleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return legacyScheduleText
    }

    private var hasScheduleValue: Bool {
        scheduleUsesTimeRange || scheduleDisplayText != nil
    }

    private var draftStartTimeBinding: Binding<Date> {
        Binding(
            get: { draftScheduleStartTime },
            set: { newValue in
                draftScheduleStartTime = newValue
            }
        )
    }

    private var draftEndTimeBinding: Binding<Date> {
        Binding(
            get: { draftScheduleEndTime },
            set: { newValue in
                draftScheduleEndTime = newValue
            }
        )
    }

    private var payBinding: Binding<String> {
        Binding(
            get: {
                payOrRate.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "$", with: "")
            },
            set: { newValue in
                payOrRate = newValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "$", with: "")
            }
        )
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
        payOrRate = post.payOrRate.replacingOccurrences(of: "$", with: "")
        schedule = post.schedule
        contact = post.authorContact
        feedbackMessage = ""
        syncScheduleState(from: post.schedule)
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
        scheduleUsesTimeRange = false
        legacyScheduleText = nil
        scheduleStartTime = Self.defaultStartTime
        scheduleEndTime = Self.defaultEndTime
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.dismissAppKeyboard()
    }

    private func clearSchedule() {
        schedule = ""
        scheduleUsesTimeRange = false
        legacyScheduleText = nil
    }

    private func openSchedulePicker() {
        dismissKeyboard()
        draftScheduleStartTime = scheduleStartTime
        draftScheduleEndTime = scheduleEndTime
        showingSchedulePicker = true
    }

    private func applyDraftSchedule() {
        scheduleStartTime = draftScheduleStartTime
        scheduleEndTime = draftScheduleEndTime
        scheduleUsesTimeRange = true
        legacyScheduleText = nil
        updateScheduleFromTimes()
        showingSchedulePicker = false
    }

    private func updateScheduleFromTimes() {
        schedule = formattedSchedule(from: scheduleStartTime, to: scheduleEndTime)
    }

    private func syncScheduleState(from rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearSchedule()
            scheduleStartTime = Self.defaultStartTime
            scheduleEndTime = Self.defaultEndTime
            return
        }

        if let parsedRange = parseScheduleRange(trimmed) {
            scheduleStartTime = parsedRange.start
            scheduleEndTime = parsedRange.end
            draftScheduleStartTime = parsedRange.start
            draftScheduleEndTime = parsedRange.end
            scheduleUsesTimeRange = true
            legacyScheduleText = nil
            schedule = formattedSchedule(from: parsedRange.start, to: parsedRange.end)
        } else {
            scheduleUsesTimeRange = false
            legacyScheduleText = trimmed
            schedule = trimmed
        }
    }

    private func parseScheduleRange(_ value: String) -> (start: Date, end: Date)? {
        let pieces = value.components(separatedBy: " - ")
        guard pieces.count == 2,
              let start = Self.scheduleFormatters.lazy.compactMap({ $0.date(from: pieces[0]) }).first,
              let end = Self.scheduleFormatters.lazy.compactMap({ $0.date(from: pieces[1]) }).first else {
            return nil
        }
        return (start, end)
    }

    private func formattedSchedule(from start: Date, to end: Date) -> String {
        "\(Self.scheduleDisplayFormatter.string(from: start)) - \(Self.scheduleDisplayFormatter.string(from: end))"
    }

    private static var defaultStartTime: Date {
        Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? .now
    }

    private static var defaultEndTime: Date {
        Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? .now
    }

    private static var scheduleDisplayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private static var scheduleFormatters: [DateFormatter] {
        ["h:mm a", "h a"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }
}
