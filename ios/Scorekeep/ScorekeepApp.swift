import SwiftUI

@main
struct ScorekeepApp: App {
    private let demo = DemoScenario.current
    @State private var viewModel: GameViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _viewModel = State(initialValue: DemoScenario.current?.makeViewModel() ?? GameViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(demo: demo)
                .environment(viewModel)
        }
        .onChange(of: scenePhase) { _, phase in
            // Saves are debounced; flush before the app can be suspended or closed.
            if phase != .active {
                viewModel.saveNow()
            }
        }
    }
}
