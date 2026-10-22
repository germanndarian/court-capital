import Foundation
import SwiftData
import Testing

/// The store syncing from a fake Notion into an in-memory cache: one record per page, each
/// page downloaded once, and unreadable pages remembered until they change.
@MainActor
@Suite("Edition store with Notion")
struct EditionStoreTests {
    private let container = try! ModelContainer(for: StoredEdition.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    private let fake = FakeNotion()
    /// Long enough ago that Notion's minute rounding doesn't come into it.
    private let earlier = Date.now.addingTimeInterval(-3 * 3600)

    init() {
        fake.setChildren(of: FakeNotion.rootID, [
            Block.childPage("Edition — Thursday, 8 October 2026", id: "oct08", created: earlier + 40, edited: earlier + 40),
            Block.childPage("Edition — Wednesday, 7 October 2026", id: "oct07", created: earlier + 30, edited: earlier + 30),
            Block.childPage("Edition — Tuesday, 6 October 2026", id: "oct06", created: earlier + 20, edited: earlier + 20),
            Block.childPage("Edition — Monday, 5 October 2026", id: "oct05", created: earlier + 10, edited: earlier + 10),
        ])
        fake.setChildren(of: "oct08", [Block.heading("Data"), Block.code(Fixture.chunks(Fixture.edition("2026-10-08")))])
        fake.setChildren(of: "oct07", [Block.heading("Data"), Block.code(Fixture.chunks(Fixture.edition("2026-10-07")))])
        fake.setChildren(of: "oct06", [Block.paragraph("Written before the Data block existed")])
        fake.setChildren(of: "oct05", [Block.heading("Data"), Block.code(["{ \"date\": \"2026-10-05\", "])])
    }

    private func makeStore() -> EditionStore {
        EditionStore(context: container.mainContext, feed: fake.feed())
    }

    private var records: [StoredEdition] {
        (try? container.mainContext.fetch(FetchDescriptor<StoredEdition>())) ?? []
    }

    @Test("Keeps one record per page and shows the readable ones")
    func firstSync() async {
        let store = makeStore()
        await store.refresh()

        #expect(store.refreshProblem == nil)
        #expect(store.editions.map(\.date) == ["2026-10-08", "2026-10-07"])
        #expect(records.count == 4)
        #expect(Set(records.filter { !$0.isReadable }.map(\.pageID)) == ["oct06", "oct05"])
        #expect(fake.requests.count == 5)
    }

    @Test("Doesn't download unchanged pages again, readable or not")
    func secondSync() async {
        let store = makeStore()
        await store.refresh()
        await store.refresh()

        #expect(fake.requests.count == 6)
        #expect(fake.requests(for: FakeNotion.rootID).count == 2)
        #expect(store.editions.count == 2)
    }

    @Test("Downloads a page again once it's edited, such as a Data block added later")
    func editedPage() async {
        let store = makeStore()
        await store.refresh()

        fake.setChildren(of: FakeNotion.rootID, [
            Block.childPage("Edition — Thursday, 8 October 2026", id: "oct08", created: earlier + 40, edited: earlier + 40),
            Block.childPage("Edition — Wednesday, 7 October 2026", id: "oct07", created: earlier + 30, edited: earlier + 30),
            Block.childPage("Edition — Tuesday, 6 October 2026", id: "oct06", created: earlier + 20, edited: earlier + 600),
            Block.childPage("Edition — Monday, 5 October 2026", id: "oct05", created: earlier + 10, edited: earlier + 10),
        ])
        fake.setChildren(of: "oct06", [Block.heading("Data"), Block.code(Fixture.chunks(Fixture.edition("2026-10-07", redatedTo: "2026-10-06")))])
        await store.refresh()

        #expect(fake.requests(for: "oct06").count == 2)
        #expect(fake.requests(for: "oct05").count == 1)
        #expect(store.editions.map(\.date) == ["2026-10-08", "2026-10-07", "2026-10-06"])
    }

    @Test("A page whose download fails is tried again on the next sync")
    func failedDownload() async {
        let store = makeStore()
        fake.reply(.init(status: 503), for: "oct07")
        await store.refresh()

        #expect(store.refreshProblem != nil)
        #expect(store.editions.map(\.date) == ["2026-10-08"])
        #expect(!records.contains { $0.pageID == "oct07" })

        await store.refresh()

        #expect(store.refreshProblem == nil)
        #expect(store.editions.map(\.date) == ["2026-10-08", "2026-10-07"])
        #expect(fake.requests(for: "oct08").count == 1)
        #expect(fake.requests(for: "oct07").count == 2)
    }

    @Test("A page checked in the same minute as its last edit is checked again")
    func editedThisMinute() async {
        let thisMinute = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 / 60).rounded(.down) * 60)
        fake.setChildren(of: FakeNotion.rootID, [
            Block.childPage("Edition — Thursday, 8 October 2026", id: "oct08", created: thisMinute, edited: thisMinute),
            Block.childPage("Edition — Wednesday, 7 October 2026", id: "oct07", created: earlier, edited: earlier),
        ])
        let store = makeStore()
        await store.refresh()
        await store.refresh()

        #expect(fake.requests(for: "oct08").count == 2)
        #expect(fake.requests(for: "oct07").count == 1)
    }

    @Test("Notes when the newest page can't be read")
    func newestUnreadable() async {
        fake.setChildren(of: FakeNotion.rootID, [
            Block.childPage("Edition — Tuesday, 6 October 2026", id: "oct06", created: earlier + 20, edited: earlier + 20),
            Block.childPage("Edition — Wednesday, 7 October 2026", id: "oct07", created: earlier, edited: earlier),
        ])
        let store = makeStore()
        await store.refresh()

        #expect(store.newestIsUnreadable)
        #expect(store.latest?.date == "2026-10-07")
    }
}
