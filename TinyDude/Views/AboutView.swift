import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("Tiny Dude")
                .font(.title.weight(.bold))

            Text("Version \(appVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Batch image compression for macOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Text("© 2026 Tiny Dude. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://tinydude.app/privacy")!)
                    .font(.caption)
                Link("Terms of Use", destination: URL(string: "https://tinydude.app/terms")!)
                    .font(.caption)
            }
        }
        .padding(32)
        .frame(width: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About Tiny Dude")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
