import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dockに表示しない
let delegate = AppDelegate()
app.delegate = delegate
app.run()
