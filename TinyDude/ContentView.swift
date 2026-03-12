import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()

    var body: some View {
        HSplitView {
            // Main area
            mainArea
                .frame(minWidth: 420, maxWidth: .infinity, minHeight: 400)

            // Settings sidebar
            SettingsPanel()
                .environmentObject(vm)
                .frame(width: 260)
                .accessibilityLabel("Compression Settings")
        }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $vm.showSummary) {
            CompletionSummaryView()
                .environmentObject(vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            openFilePicker()
        }
    }

    // MARK: - Main area

    @ViewBuilder
    private var mainArea: some View {
        if vm.items.isEmpty {
            DropZoneView()
                .environmentObject(vm)
                .padding(20)
        } else {
            ImageQueueView()
                .environmentObject(vm)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Overall progress
                if vm.isProcessing || (vm.overallProgress > 0 && vm.overallProgress < 1) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Processing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(vm.completedCount)/\(vm.totalCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: vm.overallProgress)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                    }
                    .frame(maxWidth: 220)
                } else {
                    // Size summary
                    if !vm.items.isEmpty {
                        let total = vm.items.reduce(Int64(0)) { $0 + $1.originalSize }
                        Text("\(vm.items.count) images · \(total.formattedFileSize) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Cancel / Compress button
                if vm.isProcessing {
                    Button("Cancel") { vm.cancelCompression() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Cancel compression")
                        .accessibilityHint("Stops the current batch compression")
                } else {
                    Button {
                        vm.startCompression()
                    } label: {
                        Label("Compress", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(vm.items.filter(\.isPending).isEmpty && vm.items.filter(\.isFailed).isEmpty)
                    .accessibilityLabel("Compress images")
                    .accessibilityHint("Start compressing all queued images. Command Return.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Text("Tiny Dude")
                .font(.headline)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                openFilePicker()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add Images")
            .accessibilityLabel("Add images")
            .accessibilityHint("Open file picker to select images for compression")
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Add Images"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .gif, .bmp, .heic, .image]
        if panel.runModal() == .OK { vm.addURLs(panel.urls) }
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
