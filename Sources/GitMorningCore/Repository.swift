import Foundation

public enum Feed: String, CaseIterable, Identifiable, Codable {
    case daily, weekly, saved
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .daily: return "Today’s Trending"
        case .weekly: return "Weekly Trending"
        case .saved: return "Saved"
        }
    }
    public var symbol: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar"
        case .saved: return "bookmark"
        }
    }
}

public struct Repository: Identifiable, Codable, Hashable {
    public let id: String
    public let owner: String
    public let language: String
    public let summary: String
    public let introduction: String
    public let features: [String]
    public let usage: String
    public let stars: Int?
    public let dailyGain: Int?
    public let weeklyGain: Int?
    public let summaryAvailable: Bool
    public let capturedAt: String?
    public let capturedPeriod: String
    /// A README excerpt shown next to the description. Nil when there is none, or when it already is the summary.
    public let readmeExcerpt: String?
    /// True when GitHub had no description and the summary is the README excerpt.
    public let summaryFromReadme: Bool?
    public var name: String { id.split(separator: "/").last.map(String.init) ?? id }
    public var fullName: String { id.contains("/") ? id : "\(owner)/\(id)" }
    public var githubURL: URL? {
        guard fullName.range(of: "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://github.com/" + fullName)
    }
    public func gain(for feed: Feed) -> Int? { (feed == .weekly || (feed == .saved && capturedPeriod == "weekly")) ? weeklyGain : dailyGain }
    public func gainLabel(for feed: Feed) -> String {
        if feed == .saved { return capturedPeriod == "weekly" ? "Saved weekly growth" : "Saved daily growth" }
        return feed == .weekly ? "Weekly growth" : "Daily growth"
    }
    public init(id: String, owner: String, language: String, summary: String, introduction: String, features: [String], usage: String, stars: Int?, dailyGain: Int?, weeklyGain: Int?, summaryAvailable: Bool = true, capturedAt: String? = nil, capturedPeriod: String = "daily", readmeExcerpt: String? = nil, summaryFromReadme: Bool? = nil) {
        self.id = id; self.owner = owner; self.language = language; self.summary = summary
        self.introduction = introduction; self.features = features; self.usage = usage
        self.stars = stars; self.dailyGain = dailyGain; self.weeklyGain = weeklyGain
        self.summaryAvailable = summaryAvailable; self.capturedAt = capturedAt; self.capturedPeriod = capturedPeriod
        self.readmeExcerpt = readmeExcerpt; self.summaryFromReadme = summaryFromReadme
    }
    /// The README excerpt as its own item, so description translation can translate and cache it the same way.
    public var readmeExcerptItem: Repository? {
        readmeExcerpt.map { Repository(id: id, owner: owner, language: language, summary: $0, introduction: $0, features: [], usage: "", stars: stars, dailyGain: dailyGain, weeklyGain: weeklyGain, summaryAvailable: false, capturedAt: capturedAt, capturedPeriod: capturedPeriod) }
    }
    /// A usable excerpt: trimmed, non-empty, and short enough to be an excerpt rather than a whole README.
    static func excerpt(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text.count <= 600 else { return nil }
        return text
    }
    public static func from(_ snapshot: TrendSnapshot) -> [Repository] {
        snapshot.repositories.map {
            let excerpt = excerpt($0.readmeExcerpt)
            // No GitHub description: the README excerpt becomes the summary instead of "No description".
            let fromReadme = $0.description.isEmpty && excerpt != nil
            let summary = fromReadme ? excerpt! : $0.description
            return Repository(id: $0.id, owner: $0.owner, language: $0.language ?? "Unknown", summary: summary.isEmpty ? "No description provided." : summary,
                       introduction: summary.isEmpty ? "No description was provided on GitHub Trending. Open the repository for details." : summary,
                       features: [], usage: "", stars: $0.stars,
                       dailyGain: snapshot.period == "daily" ? $0.periodStars : nil,
                       weeklyGain: snapshot.period == "weekly" ? $0.periodStars : nil,
                       summaryAvailable: false, capturedAt: snapshot.collectedAt, capturedPeriod: snapshot.period,
                       readmeExcerpt: fromReadme ? nil : excerpt, summaryFromReadme: fromReadme ? true : nil)
        }
    }

    public static let samples: [Repository] = [
        .init(id: "docnest", owner: "openkit", language: "Python", summary: "내 문서를 검색하고 질문하는 개인용 AI 도구", introduction: "여러 문서를 한곳에 모아 질문하고, 답변에 연결된 문서 내용을 확인하는 도구를 가정한 예시입니다. 수업 자료나 팀 문서에서 필요한 내용을 찾는 상황을 보여줍니다.", features: ["문서 업로드와 검색", "답변의 근거 문서 표시", "프로젝트별 자료 모음"], usage: "강의 자료를 모아 과제에 필요한 내용을 찾아보는 개인 학습 도우미.", stars: 24180, dailyGain: 1248, weeklyGain: 5840),
        .init(id: "flowline", owner: "devtools", language: "TypeScript", summary: "반복하는 개발 작업을 연결하는 자동화 도구", introduction: "빌드, 검사, 결과 알림을 하나의 흐름으로 묶는 도구를 가정한 예시입니다. 반복 작업의 순서와 결과를 확인하는 상황입니다.", features: ["작업 단계 연결", "실행 결과 확인", "설정 파일로 흐름 공유"], usage: "팀 프로젝트의 코드 검사와 문서 생성을 한 번에 실행하는 작업 흐름.", stars: 12640, dailyGain: 836, weeklyGain: 4120),
        .init(id: "tinyindex", owner: "search-lab", language: "Rust", summary: "앱 안에 넣는 작은 검색 엔진", introduction: "개인 앱의 콘텐츠를 색인하고 검색하는 라이브러리를 가정한 예시입니다. 로컬 데이터에 검색 기능을 붙이는 상황을 보여줍니다.", features: ["텍스트 색인", "검색 결과 정렬", "로컬 데이터 검색"], usage: "메모 앱에서 제목과 본문을 검색하는 기능.", stars: 8925, dailyGain: 624, weeklyGain: 2310),
        .init(id: "windowkit", owner: "native-lab", language: "Swift", summary: "맥 앱의 창과 단축키 구성을 돕는 도구", introduction: "macOS 앱에서 자주 필요한 창 동작을 정리한 도구를 가정한 예시입니다. 기본 창 구성과 키보드 동작을 구현하는 상황입니다.", features: ["창 상태 관리", "명령과 단축키 연결", "설정 화면 구성"], usage: "새 Mac 앱에서 목록과 상세를 갖춘 창 구성.", stars: 3412, dailyGain: 318, weeklyGain: 980),
        .init(id: "dockyard", owner: "build-lab", language: "Go", summary: "로컬 개발 서비스를 한곳에서 관리하는 CLI", introduction: "여러 개발 서비스를 명령줄에서 관리하는 도구를 가정한 예시입니다. 프로젝트별 실행 상태를 확인하는 상황입니다.", features: ["서비스 시작과 종료", "상태와 로그 확인", "프로젝트 설정 관리"], usage: "팀 프로젝트의 로컬 개발 환경을 같은 흐름으로 실행하기.", stars: 6210, dailyGain: 287, weeklyGain: 1640)
    ]
}

public struct Bookmark: Codable, Equatable {
    public let repositoryID: String
    public let savedAt: Date
    public init(repositoryID: String, savedAt: Date = Date()) {
        self.repositoryID = repositoryID
        self.savedAt = savedAt
    }
}

public enum Catalog {
    // Input order represents the source's Trending rank, never total-star order.
    public static func filter(_ repositories: [Repository], feed: Feed, language: String?, query: String, bookmarks: [Bookmark]) -> [Repository] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = Dictionary(bookmarks.map { ($0.repositoryID, $0.savedAt) }, uniquingKeysWith: max)
        let matches = repositories.filter { repo in
            (feed != .saved || saved[repo.id] != nil)
            && (language == nil || repo.language == language)
            && (needle.isEmpty || "\(repo.fullName) \(repo.summary)".localizedStandardContains(needle))
        }
        if feed == .saved {
            return matches.sorted {
                let lhs = saved[$0.id] ?? .distantPast, rhs = saved[$1.id] ?? .distantPast
                return lhs == rhs ? $0.id < $1.id : lhs > rhs
            }
        }
        return matches
    }
}

public struct BookmarkStorage {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> [Bookmark] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Bookmark].self, from: Data(contentsOf: url))
    }
    public func save(_ bookmarks: [Bookmark]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(bookmarks).write(to: url, options: .atomic)
    }
}
