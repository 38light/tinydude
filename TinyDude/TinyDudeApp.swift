import SwiftUI

@main
struct TinyDudeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // Replace About menu item with custom About window
            CommandGroup(replacing: .appInfo) {
                Button("About Tiny Dude") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: aboutPanelOptions)
                }
            }

            // Replace New Window command with Add Images
            CommandGroup(replacing: .newItem) {
                Button("Add Images…") {
                    NotificationCenter.default.post(name: .openFilePicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        // About window (standalone)
        Window("About Tiny Dude", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }

    private var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: "Tiny Dude",
            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            .version: "",
            .credits: NSAttributedString(
                string: "Batch image compression for macOS.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: {
                        let ps = NSMutableParagraphStyle()
                        ps.alignment = .center
                        return ps
                    }()
                ]
            )
        ]
    }
}

extension Notification.Name {
    static let openFilePicker = Notification.Name("TinyDudeOpenFilePicker")
}
