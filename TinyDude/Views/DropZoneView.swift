import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject var vm: ContentViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(vm.isDragTargeted
                      ? Color.accentColor.opacity(0.12)
                      : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            vm.isDragTargeted ? Color.accentColor : Color(NSColor.separatorColor),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )

            VStack(spacing: 16) {
                Image(systemName: vm.isDragTargeted ? "arrow.down.circle.fill" : "photo.on.rectangle.angled")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(vm.isDragTargeted ? Color.accentColor : .secondary)
                    .animation(.spring(response: 0.3), value: vm.isDragTargeted)

                Text("Drop Images Here")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.primary)

                Text("JPEG, PNG, WebP, AVIF, HEIC, TIFF and more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Browse Files…") { openFilePicker() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint("Open file picker to select images")
            }
            .padding(40)
        }
        .onDrop(of: [.fileURL], isTargeted: $vm.isDragTargeted) { providers in
            handleDrop(providers)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop zone")
        .accessibilityHint("Drag and drop images here or use the Browse Files button")
    }

    // MARK: - Helpers

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Images"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = imageContentTypes()
        if panel.runModal() == .OK {
            vm.addURLs(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let validProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !validProviders.isEmpty else { return false }

        let lock = NSLock()
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in validProviders {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            vm.addURLs(urls)
        }
        return true
    }

    private func imageContentTypes() -> [UTType] {
        var types: [UTType] = [.jpeg, .png, .tiff, .gif, .bmp, .heic]
        if #available(macOS 12.0, *) {
            if let webp = UTType("org.webmproject.webp") { types.append(webp) }
        }
        if #available(macOS 13.0, *) {
            if let avif = UTType("public.avif") { types.append(avif) }
        }
        return types
    }
}
