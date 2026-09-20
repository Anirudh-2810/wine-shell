import Foundation

#if canImport(SwiftUI)
import WineShellUI

@main
struct WineShellMain {
    static func main() { WineShellApp.main() }
}
#else
@main
struct WineShellLinuxMain {
    static func main() {
        print("wine-shell GUI requires macOS — use WineKit as a library here.")
    }
}
#endif
