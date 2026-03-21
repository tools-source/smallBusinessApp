import CoreLocation
import SwiftUI

private enum FeedPostFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case hiring = "Hiring"
    case seeking = "Looking For Work"

    var id: String { rawValue }
}

private enum FeedSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case topRated = "Top Rated"
    case mostActive = "Most Active"
    case nearest = "Nearest"

    var id: String { rawValue }
}

struct HomeFeedView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationManager: AppLocationManager

    @State private var searchText = ""
    @State private var filter: FeedPostFilter = .all
    @State private var category: BusinessCategory? = nil
    @State private var sort: FeedSort = .newest
    @State private var distanceByPostID: [UUID: CLLocationDistance] = [:]
    @State private var hasAutoSelectedNearest = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                feedHero
                filterBar

                if filteredPosts.isEmpty {
                    AppPanel {
                        VStack(spacing: 14) {
                            Image(systemName: "tray")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text("No posts available")
                                .font(.headline)

                            Text(emptyStateMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                ForEach(filteredPosts) { post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post, distanceText: distanceText(for: post))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 20)
        }
        .background(AppChromeBackground())
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .appKeyboardDismissable()
        .onAppear {
            if let role = store.currentUser?.role {
                filter = role == .worker ? .hiring : .seeking
            }
            locationManager.refreshLocation()
        }
        .task(id: distanceRefreshKey) {
            await refreshDistances()
        }
    }

    private var feedHero: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 18) {
                AppBadge(
                    title: roleHeaderBadge,
                    systemImage: roleHeaderIcon,
                    tint: currentRole == .business ? AppTheme.warmSand : .accentColor
                )

                AppSectionHeader(
                    eyebrow: "Local marketplace",
                    title: heroTitle,
                    subtitle: heroSubtitle
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                    AppBadge(title: "\(filteredPosts.count) live", systemImage: "sparkles", tint: .green)
                    AppBadge(title: sort.rawValue, systemImage: "arrow.up.arrow.down", tint: .accentColor)
                    if let category {
                        AppBadge(title: category.title, systemImage: "tag.fill", tint: AppTheme.warmSand)
                    }
                        if let currentAddress = AppLocationManager.shortAddress(locationManager.currentAddress) {
                            AppBadge(title: currentAddress, systemImage: "location.fill", tint: .accentColor)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateMessage: String {
        switch store.currentUser?.role {
        case .worker:
            return "Try changing filters to find business job openings."
        case .business:
            return "Try changing filters to find worker profiles."
        case .none:
            return "Try changing filters or create a new post."
        }
    }

    private var filterBar: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionHeader(
                    eyebrow: "Discover",
                    title: "Search and narrow the board",
                    subtitle: "Filter by post type, business category, and activity so the list stays useful."
                )

                searchField

                liveLocationRow

                summaryStrip

                HStack {
                    Text("Results")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Menu {
                        Picker("Sort By", selection: $sort) {
                            ForEach(FeedSort.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                    } label: {
                        AppBadge(title: sort.rawValue, systemImage: "arrow.up.arrow.down", tint: .accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Picker("Post Type", selection: $filter) {
                    ForEach(FeedPostFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(title: "All", active: category == nil) {
                            category = nil
                        }
                        ForEach(BusinessCategory.allCases) { item in
                            categoryChip(title: item.title, active: category == item) {
                                category = item
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Search title, details, or location", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .appFieldStyle()
    }

    private var liveLocationRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let currentAddress = AppLocationManager.shortAddress(locationManager.currentAddress) {
                    AppBadge(title: currentAddress, systemImage: "location.fill", tint: .accentColor)
                } else {
                    AppBadge(
                        title: locationManager.isAuthorized ? "Locating nearby posts" : "Live location off",
                        systemImage: "location.slash",
                        tint: .orange
                    )
                }

                Spacer()

                Button {
                    locationManager.refreshLocation()
                } label: {
                    AppBadge(
                        title: locationManager.isAuthorized ? "Refresh" : "Enable",
                        systemImage: "location.circle.fill",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)
            }

            if let lastErrorMessage = locationManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Choose Nearest to rank posts by distance from your current device location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(summaryItems, id: \.title) { item in
                    DashboardStatCard(
                        title: item.title,
                        value: item.value,
                        systemImage: item.systemImage,
                        caption: item.caption,
                        tint: item.tint
                    )
                    .frame(width: 180)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var summaryItems: [(title: String, value: String, systemImage: String, caption: String, tint: Color)] {
        let openJobs = store.sortedPosts.filter { $0.postType == .employerHiring }.count
        let workerProfiles = store.sortedPosts.filter { $0.postType == .workerSeeking }.count
        let applied = store.mySubmittedApplications.count
        let received = store.myReceivedApplications.count

        switch store.currentUser?.role {
        case .worker:
            return [
                ("Open Jobs", "\(openJobs)", "briefcase.fill", "Hiring posts available now", .accentColor),
                ("Worker Profiles", "\(workerProfiles)", "person.2.fill", "Public worker profiles on the board", .orange),
                ("Your Applications", "\(applied)", "paperplane.fill", "Track progress from the applications tab", .green)
            ]
        case .business:
            return [
                ("Worker Profiles", "\(workerProfiles)", "person.2.fill", "Workers looking for opportunities", .accentColor),
                ("Open Jobs", "\(openJobs)", "briefcase.fill", "Public business openings on the board", .orange),
                ("Applications", "\(received)", "tray.full.fill", "Applications received across your business", .green)
            ]
        case .none:
            return [
                ("Open Jobs", "\(openJobs)", "briefcase.fill", "Business openings on the board", .accentColor),
                ("Worker Profiles", "\(workerProfiles)", "person.2.fill", "Workers open to new roles", .orange),
                ("Marketplace", "\(store.sortedPosts.count)", "sparkles", "Live posts across both sides", .green)
            ]
        }
    }

    private func categoryChip(title: String, active: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(active ? Color.accentColor : Color.primary.opacity(0.06))
                .foregroundStyle(active ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var currentRole: UserRole {
        store.currentUser?.role ?? .worker
    }

    private var heroTitle: String {
        switch currentRole {
        case .worker:
            return "Open jobs near you"
        case .business:
            return "Available workers in your area"
        }
    }

    private var heroSubtitle: String {
        switch currentRole {
        case .worker:
            return "Review hiring posts, compare ratings, and move straight into verified applications."
        case .business:
            return "Scan worker profiles, compare reputation, and reach out through the applications flow."
        }
    }

    private var roleHeaderBadge: String {
        currentRole == .worker ? "Worker feed" : "Business feed"
    }

    private var roleHeaderIcon: String {
        currentRole.icon
    }

    private var distanceRefreshKey: String {
        let postKey = store.sortedPosts.map { $0.id.uuidString }.joined(separator: "|")
        let locationKey: String
        if let currentLocation = locationManager.currentLocation {
            locationKey = String(format: "%.4f-%.4f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude)
        } else {
            locationKey = "no-location"
        }
        return locationKey + "|" + postKey
    }

    private var filteredPosts: [JobPost] {
        let filtered = store.sortedPosts.filter { post in
            let matchesType: Bool
            switch filter {
            case .all: matchesType = true
            case .hiring: matchesType = post.postType == .employerHiring
            case .seeking: matchesType = post.postType == .workerSeeking
            }

            let matchesCategory = category == nil || post.category == category

            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || {
                let query = searchText.lowercased()
                return post.title.lowercased().contains(query)
                    || post.details.lowercased().contains(query)
                    || post.location.lowercased().contains(query)
                    || post.authorName.lowercased().contains(query)
            }()

            return matchesType && matchesCategory && matchesSearch
        }

        return filtered.sorted { lhs, rhs in
            sortComparator(lhs: lhs, rhs: rhs)
        }
    }

    private func sortComparator(lhs: JobPost, rhs: JobPost) -> Bool {
        switch sort {
        case .newest:
            return lhs.createdAt > rhs.createdAt
        case .topRated:
            let lhsRating = store.ratingSummary(for: lhs.authorID)
            let rhsRating = store.ratingSummary(for: rhs.authorID)
            if lhsRating.average != rhsRating.average {
                return lhsRating.average > rhsRating.average
            }
            if lhsRating.count != rhsRating.count {
                return lhsRating.count > rhsRating.count
            }
            return lhs.createdAt > rhs.createdAt
        case .mostActive:
            let lhsScore = activityScore(for: lhs)
            let rhsScore = activityScore(for: rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.createdAt > rhs.createdAt
        case .nearest:
            let lhsDistance = distanceByPostID[lhs.id]
            let rhsDistance = distanceByPostID[rhs.id]

            switch (lhsDistance, rhsDistance) {
            case let (lhsDistance?, rhsDistance?):
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.createdAt > rhs.createdAt
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func activityScore(for post: JobPost) -> Int {
        switch post.postType {
        case .employerHiring:
            return store.applicationCount(for: post.id)
        case .workerSeeking:
            return store.ratingSummary(for: post.authorID).count
        }
    }

    private func distanceText(for post: JobPost) -> String? {
        guard let distance = distanceByPostID[post.id] else { return nil }
        let miles = distance / 1609.344
        if miles < 0.1 {
            return "<0.1 mi away"
        }
        return String(format: "%.1f mi away", miles)
    }

    private func refreshDistances() async {
        guard locationManager.currentLocation != nil else {
            distanceByPostID = [:]
            return
        }

        var refreshedDistances: [UUID: CLLocationDistance] = [:]
        for post in store.sortedPosts {
            if let distance = await locationManager.distance(to: post.location) {
                refreshedDistances[post.id] = distance
            }
        }

        distanceByPostID = refreshedDistances
        if !hasAutoSelectedNearest, !refreshedDistances.isEmpty {
            sort = .nearest
            hasAutoSelectedNearest = true
        }
    }
}

private struct PostCardView: View {
    @EnvironmentObject private var store: AppStore

    let post: JobPost
    var distanceText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AppBadge(
                    title: post.postType.title,
                    systemImage: post.postType.icon,
                    tint: AppTint.postType(post.postType)
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(post.createdAt, style: .date)
                        .font(.caption.weight(.semibold))
                    Text(post.createdAt, style: .time)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.title3.weight(.bold))

            Text(post.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AppBadge(title: post.category.title, systemImage: "tag.fill", tint: AppTheme.warmSand)
                    AppBadge(title: post.location, systemImage: "mappin.and.ellipse", tint: .accentColor)
                    if let distanceText {
                        AppBadge(title: distanceText, systemImage: "location.fill", tint: .green)
                    }
                }
            }

            Divider()
                .opacity(0.45)

            HStack {
                UserAvatarView(
                    user: store.user(for: post.authorID),
                    fallbackName: post.authorName,
                    fallbackRole: post.authorRole,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(post.authorRole.title) • \(store.ratingSummary(for: post.authorID).compactText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let applicationSummary {
                AppBadge(title: applicationSummary, systemImage: applicationSummaryIcon, tint: .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle(padding: 18, cornerRadius: 24)
    }

    private var applicationSummary: String? {
        guard let currentUser = store.currentUser else { return nil }

        if currentUser.role == .worker,
           let application = store.currentUserApplication(for: post.id) {
            return "Applied • \(application.status.title)"
        }

        if currentUser.id == post.authorID, post.postType == .employerHiring {
            let count = store.applicationCount(for: post.id)
            return count == 0 ? "No applications yet" : "\(count) \(count == 1 ? "application" : "applications")"
        }

        return nil
    }

    private var applicationSummaryIcon: String {
        guard let currentUser = store.currentUser else { return "tray" }

        if currentUser.role == .worker,
           let application = store.currentUserApplication(for: post.id) {
            return application.status.systemImage
        }

        return "tray.full"
    }
}
