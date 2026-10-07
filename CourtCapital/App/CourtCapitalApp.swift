import SwiftUI

@main
struct CourtCapitalApp: App {
    @State private var model = AppModel()
    @AppStorage(Preferences.appearance) private var appearance = Appearance.automatic

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.handle($0) }
                .onAppear { appearance.apply(animated: false) }
                .onChange(of: appearance) { _, newValue in newValue.apply(animated: true) }
        }
    }
}
