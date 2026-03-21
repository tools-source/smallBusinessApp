import SwiftUI

private struct ApplicationGroup: Identifiable {
    let postID: UUID
    let postTitle: String
    let applications: [JobApplication]

    var id: UUID { postID }
}

private enum ApplicationStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case open = "Open"
    case hired = "Hired"
    case declined = "Declined"

    var id: String { rawValue }

    func matches(_ status: ApplicationStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .open:
            return status == .pending || status == .reviewed || status == .contacted
        case .hired:
            return status == .hired
        case .declined:
            return status == .declined
        }
    }
}

struct ApplicationsView: View {
    @EnvironmentObject private var store: AppStore

    let initialPostID: UUID?
    @State private var statusFilter: ApplicationStatusFilter = .open

    init(initialPostID: UUID? = nil) {
        self.initialPostID = initialPostID
    }

    private var currentRole: UserRole {
        store.currentUser?.role ?? .worker
    }

    private var filteredReceivedApplications: [JobApplication] {
        store.myReceivedApplications.filter { application in
            (initialPostID == nil || application.postID == initialPostID)
                && statusFilter.matches(application.status)
        }
    }

    private var receivedGroups: [ApplicationGroup] {
        Dictionary(grouping: filteredReceivedApplications, by: \.postID)
            .compactMap { postID, applications in
                guard let first = applications.first else { return nil }
                return ApplicationGroup(
                    postID: postID,
                    postTitle: first.postTitle,
                    applications: applications.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.applications.first?.updatedAt ?? .distantPast
                let rhsDate = rhs.applications.first?.updatedAt ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    private var submittedApplications: [JobApplication] {
        store.mySubmittedApplications.filter { application in
            (initialPostID == nil || application.postID == initialPostID)
                && statusFilter.matches(application.status)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                applicationsHeader

                if isEmptyStateVisible {
                    AppPanel {
                        VStack(spacing: 14) {
                            Image(systemName: emptySystemImage)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(emptyTitle)
                                .font(.headline)

                            Text(emptyMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else if currentRole == .business {
                    ForEach(receivedGroups) { group in
                        receivedGroupCard(group)
                    }
                } else {
                    ForEach(submittedApplications) { application in
                        NavigationLink {
                            ApplicationDetailView(applicationID: application.id)
                        } label: {
                            ApplicationRowView(application: application, perspective: .worker)
                                .appPanelStyle(padding: 18, cornerRadius: 24)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 20)
        }
        .background(AppChromeBackground())
        .navigationTitle(initialPostID == nil ? "Applications" : "Job Applications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if currentRole == .worker && statusFilter == .open && submittedApplications.isEmpty {
                statusFilter = .all
            }
        }
    }

    private var isEmptyStateVisible: Bool {
        currentRole == .business ? receivedGroups.isEmpty : submittedApplications.isEmpty
    }

    private var emptyTitle: String {
        currentRole == .business ? "No Applications Yet" : "No Applications Sent"
    }

    private var emptySystemImage: String {
        currentRole == .business ? "tray" : "paperplane"
    }

    private var emptyMessage: String {
        if currentRole == .business {
            return initialPostID == nil
                ? "Worker applications to your job openings will appear here."
                : "Workers have not applied to this job opening yet."
        }
        return "Apply to business job posts to track your submissions here."
    }

    private var applicationsHeader: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppBadge(
                    title: currentRole == .business ? "Business inbox" : "Worker tracking",
                    systemImage: currentRole.icon,
                    tint: AppTint.role(currentRole)
                )

                AppSectionHeader(
                    eyebrow: "Applications",
                    title: currentRole == .business ? "Review incoming candidates" : "Track every application",
                    subtitle: currentRole == .business
                        ? "Group applications by opening, update status quickly, and keep the hiring queue organized."
                        : "See which businesses reviewed you, contacted you, or moved you into a hire."
                )

                summaryStrip

                Picker("Status", selection: $statusFilter) {
                    ForEach(ApplicationStatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var summaryStrip: some View {
        let baseApplications = currentRole == .business ? store.myReceivedApplications : store.mySubmittedApplications
        let scopedApplications = baseApplications.filter { initialPostID == nil || $0.postID == initialPostID }
        let openCount = scopedApplications.filter { ApplicationStatusFilter.open.matches($0.status) }.count
        let hiredCount = scopedApplications.filter { $0.status == .hired }.count
        let declinedCount = scopedApplications.filter { $0.status == .declined }.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                DashboardStatCard(
                    title: "Open",
                    value: "\(openCount)",
                    systemImage: "clock.badge.checkmark",
                    caption: currentRole == .business ? "Applications still in progress" : "Businesses still reviewing you",
                    tint: .accentColor
                )
                .frame(width: 180)

                DashboardStatCard(
                    title: "Hired",
                    value: "\(hiredCount)",
                    systemImage: "checkmark.seal.fill",
                    caption: currentRole == .business ? "Successful hires from your inbox" : "Applications that turned into jobs",
                    tint: .green
                )
                .frame(width: 180)

                DashboardStatCard(
                    title: "Declined",
                    value: "\(declinedCount)",
                    systemImage: "xmark.seal",
                    caption: currentRole == .business ? "Closed or rejected applications" : "Applications that did not move forward",
                    tint: .orange
                )
                .frame(width: 180)
            }
            .padding(.vertical, 2)
        }
    }

    private func receivedGroupCard(_ group: ApplicationGroup) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.postTitle)
                            .font(.headline)

                        Text("\(group.applications.count) \(group.applications.count == 1 ? "application" : "applications")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    AppBadge(
                        title: group.applications.first?.status.title ?? "Open",
                        systemImage: group.applications.first?.status.systemImage,
                        tint: AppTint.status(group.applications.first?.status ?? .pending)
                    )
                }

                ForEach(Array(group.applications.enumerated()), id: \.element.id) { index, application in
                    if index > 0 {
                        Divider()
                            .opacity(0.45)
                    }

                    NavigationLink {
                        ApplicationDetailView(applicationID: application.id)
                    } label: {
                        ApplicationRowView(application: application, perspective: .business)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ApplicationRowView: View {
    @EnvironmentObject private var store: AppStore

    let application: JobApplication
    let perspective: UserRole

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if perspective == .business {
                    UserAvatarView(
                        user: store.user(for: application.workerUserID),
                        fallbackName: application.workerName,
                        fallbackRole: .worker,
                        explicitFileName: application.workerProfileImageFileName,
                        size: 44
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    AppBadge(
                        title: application.status.title,
                        systemImage: application.status.systemImage,
                        tint: AppTint.status(application.status)
                    )
                    Text(title)
                        .font(.headline.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(application.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                    Text(application.updatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(application.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var title: String {
        switch perspective {
        case .business:
            return application.workerName
        case .worker:
            return application.postTitle
        }
    }

    private var subtitle: String {
        switch perspective {
        case .business:
            let rating = store.ratingSummary(for: application.workerUserID).compactText
            return "\(application.workerContact) • Worker rating \(rating)"
        case .worker:
            let rating = store.ratingSummary(for: application.businessUserID).compactText
            return "\(application.businessName) • Business rating \(rating)"
        }
    }
}

struct ApplicationDetailView: View {
    @EnvironmentObject private var store: AppStore

    let applicationID: UUID

    @State private var feedbackMessage = ""

    var body: some View {
        Group {
            if let application = store.application(with: applicationID) {
                List {
                    if isBusinessOwner(application) {
                        Section("Application Status") {
                            if canManageStatus(for: application) {
                                Picker("Status", selection: statusBinding(for: application)) {
                                    ForEach(ApplicationStatus.allCases) { status in
                                        Label(status.title, systemImage: status.systemImage)
                                            .tag(status)
                                    }
                                }
                                .pickerStyle(.menu)

                                Label(application.status.title, systemImage: application.status.systemImage)
                                    .foregroundStyle(AppTint.status(application.status))
                            } else {
                                Label(application.status.title, systemImage: application.status.systemImage)
                                    .foregroundStyle(AppTint.status(application.status))
                                Text("This hire is finalized. The related posts were removed and the application status is now locked.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Section("Application Status") {
                            Label(application.status.title, systemImage: application.status.systemImage)
                                .foregroundStyle(AppTint.status(application.status))
                            Text("Businesses update your application status here as they review it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Job") {
                        Label(application.postTitle, systemImage: "briefcase.fill")
                        Label(application.businessName, systemImage: UserRole.business.icon)
                        if let jobLocation = jobLocation(for: application) {
                            Label(jobLocation, systemImage: "mappin.and.ellipse")
                        }
                        if let jobSchedule = jobSchedule(for: application) {
                            Label(jobSchedule, systemImage: "calendar")
                        }
                        if let jobPay = jobPay(for: application) {
                            Label(jobPay, systemImage: "dollarsign.circle")
                        }
                    }

                    if isBusinessOwner(application) {
                        Section("Worker") {
                            HStack(spacing: 14) {
                                UserAvatarView(
                                    user: store.user(for: application.workerUserID),
                                    fallbackName: application.workerName,
                                    fallbackRole: .worker,
                                    explicitFileName: application.workerProfileImageFileName,
                                    size: 72
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(application.workerName)
                                        .font(.headline)
                                    Text(application.workerEmail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Label(application.workerEmail, systemImage: "envelope")
                            Label(application.workerContact, systemImage: "phone")
                            Label(
                                "Worker rating: \(store.ratingSummary(for: application.workerUserID).detailText)",
                                systemImage: "star.fill"
                            )
                        }
                    } else {
                        Section("Business") {
                            Label(application.businessName, systemImage: UserRole.business.icon)
                            if let businessContact = businessContact(for: application) {
                                Label(businessContact, systemImage: "envelope")
                            }
                            if let businessPhone = businessPhone(for: application) {
                                Label(businessPhone, systemImage: "phone")
                            }
                            Label(
                                "Business rating: \(store.ratingSummary(for: application.businessUserID).detailText)",
                                systemImage: "star.fill"
                            )
                        }
                    }

                    if quickActionsAvailable(for: application) {
                        Section("Quick Actions") {
                            HStack(spacing: 10) {
                                if let emailURL = emailURL(for: application) {
                                    QuickActionLink(
                                        title: "Email",
                                        systemImage: "envelope.fill",
                                        url: emailURL
                                    )
                                }
                                if let phoneURL = phoneURL(for: application) {
                                    QuickActionLink(
                                        title: "Call",
                                        systemImage: "phone.fill",
                                        url: phoneURL,
                                        tint: .green
                                    )
                                }
                            }
                        }
                    }

                    Section(isBusinessOwner(application) ? "Worker Message" : "Your Message") {
                        Text(application.message)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(application.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    }

                    Section("Submitted Media") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Worker Profile Photo")
                                .font(.subheadline.weight(.semibold))
                            ProfilePhotoPreviewView(
                                fileName: submittedProfilePhotoFileName(for: application),
                                fallbackName: application.workerName
                            )
                            Text(application.workerProfileImageFileName == nil
                                 ? "Showing the worker's current profile photo. New applications also save a submission-time snapshot."
                                 : "This photo was attached from the worker profile at the time the application was submitted.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Government ID")
                                .font(.subheadline.weight(.semibold))
                            if let workerIDImageFileName = application.workerIDImageFileName {
                                DocumentPreviewView(fileName: workerIDImageFileName)
                                Text(isBusinessOwner(application)
                                     ? "Review the uploaded ID to verify the worker before moving forward."
                                     : "Your uploaded ID is attached to this application.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No ID image was uploaded with this application.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !feedbackMessage.isEmpty {
                        Section {
                            Text(feedbackMessage)
                                .font(.footnote)
                                .foregroundStyle(feedbackMessage == "Status updated." ? .green : .red)
                        }
                    }
                }
                .navigationTitle("Application")
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(AppChromeBackground())
            } else {
                ContentUnavailableView(
                    "Application Missing",
                    systemImage: "tray",
                    description: Text("This application is no longer available.")
                )
                .navigationTitle("Application")
                .navigationBarTitleDisplayMode(.inline)
                .background(AppChromeBackground())
            }
        }
    }

    private func isBusinessOwner(_ application: JobApplication) -> Bool {
        store.currentUser?.id == application.businessUserID
    }

    private func submittedProfilePhotoFileName(for application: JobApplication) -> String? {
        application.workerProfileImageFileName
            ?? store.user(for: application.workerUserID)?.profileImageFileName
    }

    private func canManageStatus(for application: JobApplication) -> Bool {
        store.post(for: application.postID) != nil
    }

    private func businessContact(for application: JobApplication) -> String? {
        application.businessContact
            ?? store.user(for: application.businessUserID)?.marketplaceEmail
            ?? store.post(for: application.postID)?.authorContact
    }

    private func businessPhone(for application: JobApplication) -> String? {
        store.phone(for: application.businessUserID)
            ?? ContactSupport.phoneCandidate(primary: application.businessContact)
            ?? ContactSupport.phoneCandidate(primary: store.post(for: application.postID)?.authorContact)
    }

    private func workerPhone(for application: JobApplication) -> String? {
        store.phone(for: application.workerUserID)
            ?? ContactSupport.phoneCandidate(primary: application.workerContact)
    }

    private func jobLocation(for application: JobApplication) -> String? {
        let value = application.postLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            return value
        }
        return store.post(for: application.postID)?.location
    }

    private func jobSchedule(for application: JobApplication) -> String? {
        let value = application.postSchedule.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            return value
        }
        let liveValue = store.post(for: application.postID)?.schedule ?? ""
        return liveValue.isEmpty ? nil : liveValue
    }

    private func jobPay(for application: JobApplication) -> String? {
        let value = application.postPayOrRate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            return CompensationSupport.formattedDisplay(value)
        }
        let liveValue = store.post(for: application.postID)?.payOrRate ?? ""
        return CompensationSupport.formattedDisplay(liveValue)
    }

    private func emailURL(for application: JobApplication) -> URL? {
        if isBusinessOwner(application) {
            return ContactSupport.emailURL(primary: application.workerContact, fallback: application.workerEmail)
        }
        return ContactSupport.emailURL(primary: businessContact(for: application))
    }

    private func phoneURL(for application: JobApplication) -> URL? {
        if isBusinessOwner(application) {
            return ContactSupport.phoneURL(workerPhone(for: application))
        }
        return ContactSupport.phoneURL(businessPhone(for: application))
    }

    private func quickActionsAvailable(for application: JobApplication) -> Bool {
        emailURL(for: application) != nil || phoneURL(for: application) != nil
    }

    private func statusBinding(for application: JobApplication) -> Binding<ApplicationStatus> {
        Binding(get: {
            store.application(with: application.id)?.status ?? application.status
        }, set: { newStatus in
            do {
                try store.updateApplicationStatus(application, status: newStatus)
                feedbackMessage = "Status updated."
            } catch {
                feedbackMessage = error.localizedDescription
            }
        })
    }
}
