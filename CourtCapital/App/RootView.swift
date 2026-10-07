import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            TodayTab()
                .tabContent(visible: model.tab == .today)
            ArchiveView()
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
                    if let story = model.edition.story(id: route.id) {
                        StoryView(story: story)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
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
