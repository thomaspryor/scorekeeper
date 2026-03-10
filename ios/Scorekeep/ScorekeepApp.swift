import SwiftUI

@main
struct ScorekeepApp: App {
    @State private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
    }
}
