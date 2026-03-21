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

    var id: String { rawValue }
}

struct HomeFeedView: View {
    @EnvironmentObject private var store: AppStore

    @State private var searchText = ""
    @State private var filter: FeedPostFilter = .all
    @State private var category: BusinessCategory? = nil
    @State private var sort: FeedSort = .newest

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                filterBar
                if filteredPosts.isEmpty {
                    ContentUnavailableView(
                        "No Posts Yet",
                        systemImage: "tray",
                        description: Text(emptyStateMessage)
                    )
                    .padding(.top, 60)
                }
                ForEach(filteredPosts) { post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let role = store.currentUser?.role {
                filter = role == .worker ? .hiring : .seeking
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
        VStack(spacing: 12) {
            searchField

            summaryStrip

            HStack {
                Text("Discover")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(FeedSort.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down.circle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
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
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.65)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                .background(active ? Color.accentColor : Color.secondary.opacity(0.16))
                .foregroundStyle(active ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
}

private struct PostCardView: View {
    @EnvironmentObject private var store: AppStore

    let post: JobPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label(post.postType.title, systemImage: post.postType.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(post.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.headline)

            Text(post.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Label(post.category.title, systemImage: "tag")
                Spacer()
                Label(post.location, systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

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
                Label(applicationSummary, systemImage: applicationSummaryIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
