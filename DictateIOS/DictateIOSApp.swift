#if os(iOS)
import SwiftUI

@main
struct DictateIOSApp: App {
    @State private var viewModel = DictationViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
#endif
