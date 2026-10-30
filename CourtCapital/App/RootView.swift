import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(EditionStore.self) private var store
    @Environment(DocketStore.self) private var docket

    var body: some View {
        @Bindable var model = model
        // The tab bar sits below the tabs rather than over them: a bottom safe-area inset
        // doesn't reach the scroll views inside the navigation stacks, so the end of each
        // page would stay hidden behind the bar.
        VStack(spacing: 0) {
            ZStack {
                TodayTab()
                    .tabContent(visible: model.tab == .today)
                DocketTab()
                    .tabContent(visible: model.tab == .docket)
                ArchiveTab()
                    .tabContent(visible: model.tab == .archive)
                SettingsView()
                    .tabContent(visible: model.tab == .settings)
            }
            if !model.isReadingStory {
                EditionTabBar(selection: $model.tab, marked: docket.filesWithNews.isEmpty ? [] : [.docket])
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                Toast(text: toast)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isReadingStory)
        .animation(.snappy, value: model.toast)
        .background(PaperBackground(glow: true).ignoresSafeArea())
        .sheet(item: $model.draft) { draft in
            FileEditorSheet(draft: draft)
        }
        // The docket's records come from the editions, so they follow every sync.
        .onChange(of: store.editions, initial: true) { _, editions in
            docket.update(editions: editions)
        }
        .onChange(of: docket.files) { _, files in
            Task { await DocketReminders.refresh(files) }
        }
    }
}

struct TodayTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.todayPath) {
            TodayView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: StoryRoute.self) { route in
                    StoryDestination(route: route, backTitle: "Today") { model.todayPath.removeLast() }
                }
        }
    }
}

struct ArchiveTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.archivePath) {
            ArchiveView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ArchiveRoute.self) { route in
                    switch route {
                    case .edition(let date):
                        ArchivedEditionView(date: date)
                    case .story(let story):
                        StoryDestination(route: story, backTitle: "Edition") { model.archivePath.removeLast() }
                    case .saved:
                        SavedView()
                    case .savedStory(let saved):
                        SavedStoryDestination(saved: saved, backTitle: "Saved") { model.archivePath.removeLast() }
                    }
                }
        }
    }
}

struct DocketTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.docketPath) {
            DocketView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: DocketRoute.self) { route in
                    switch route {
                    case .file(let id):
                        DocketFileView(fileID: id)
                    case .story(let story):
                        StoryDestination(route: story, backTitle: "File") { model.docketPath.removeLast() }
                    }
                }
        }
    }
}

/// Finds the story's edition (from the cache) and shows it.
struct StoryDestination: View {
    let route: StoryRoute
    let backTitle: String
    let back: () -> Void
    @Environment(EditionStore.self) private var store

    var body: some View {
        if let edition = store.cachedEdition(on: route.editionDate), let story = edition.story(id: route.storyID) {
            StoryView(placed: PlacedStory(story, in: edition), backTitle: backTitle, back: back)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            NoticeView(title: "Story unavailable", message: "This story isn’t saved on your iPhone yet.")
                .paperScreen()
        }
    }
}

/// Opens a story from the Saved shelf: the live story when its edition still has one with the
/// same headline, otherwise the copy kept with the bookmark.
struct SavedStoryDestination: View {
    let saved: SavedStory
    let backTitle: String
    let back: () -> Void
    @Environment(EditionStore.self) private var store

    var body: some View {
        StoryView(placed: saved.resolve(in: store.cachedEdition(on: saved.editionDate)), backTitle: backTitle, back: back)
            .toolbar(.hidden, for: .navigationBar)
    }
}

private extension View {
    /// Keeps every tab alive so scroll positions survive switching.
    func tabContent(visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

extension View {
    /// Paper behind the whole screen, plus a paper band under the status bar so the edition
    /// scrolls beneath it. The band is cut from the same full-screen sheet, so the night glow
    /// runs on without a seam.
    func paperScreen() -> some View {
        background(PaperBackground(glow: true).ignoresSafeArea())
            .overlay {
                GeometryReader { proxy in
                    let insets = proxy.safeAreaInsets
                    PaperBackground(glow: true)
                        .frame(height: proxy.size.height + insets.top + insets.bottom)
                        .mask(alignment: .top) { Rectangle().frame(height: insets.top) }
                        .offset(y: -insets.top)
                }
                .allowsHitTesting(false)
            }
    }
}
