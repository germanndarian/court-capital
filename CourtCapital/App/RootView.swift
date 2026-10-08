import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            TodayTab()
                .tabContent(visible: model.tab == .today)
            ArchiveTab()
                .tabContent(visible: model.tab == .archive)
            SettingsView()
                .tabContent(visible: model.tab == .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.isReadingStory {
                EditionTabBar(selection: $model.tab)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isReadingStory)
        .background(PaperBackground(glow: true).ignoresSafeArea())
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
            StoryView(edition: edition, story: story, backTitle: backTitle, back: back)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            NoticeView(title: "Story unavailable", message: "This story isn’t saved on your iPhone yet.")
                .paperScreen()
        }
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
