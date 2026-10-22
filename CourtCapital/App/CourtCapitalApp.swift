import SwiftData
import SwiftUI

@main
struct CourtCapitalApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @AppStorage(Preferences.appearance) private var appearance = Appearance.automatic
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = EditionCache.makeContainer()
        self.container = container
        _model = State(initialValue: AppModel(store: EditionStore(context: container.mainContext)))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.store)
                .onOpenURL { model.handle($0) }
                .onAppear { appearance.apply(animated: false) }
                .onChange(of: appearance) { _, newValue in newValue.apply(animated: true) }
                .task { await model.store.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await model.store.refresh() }
                    case .background:
                        BackgroundRefresh.schedule()
                    default:
                        break
                    }
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await model.store.refresh()
            BackgroundRefresh.schedule()
        }
    }
}
