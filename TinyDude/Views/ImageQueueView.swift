import SwiftUI

struct ImageQueueView: View {
    @EnvironmentObject var vm: ContentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("\(vm.items.count) image\(vm.items.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear Done") { vm.clearCompleted() }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .disabled(vm.isProcessing)
                    .accessibilityLabel("Clear completed images")
                    .accessibilityHint("Remove finished and failed images from the queue")

                Button("Clear All") { vm.clearAll() }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
                    .disabled(vm.isProcessing)
                    .accessibilityLabel("Clear all images")
                    .accessibilityHint("Remove all images from the queue")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(vm.items) { item in
                        ImageRowView(item: item)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .padding(10)
                .animation(.spring(response: 0.35), value: vm.items.count)
            }

            // Drop zone overlay (when queue is populated, still allow dropping more)
            .overlay(alignment: .bottom) {
                if !vm.isDragTargeted {
                    dropHintBar
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $vm.isDragTargeted) { providers in
                let validProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
                guard !validProviders.isEmpty else { return false }

                let lock = NSLock()
                var urls: [URL] = []
                let g = DispatchGroup()
                for p in validProviders {
                    g.enter()
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            lock.lock()
                            urls.append(url)
                            lock.unlock()
                        }
                        g.leave()
                    }
                }
                g.notify(queue: .main) { vm.addURLs(urls) }
                return true
            }
            .overlay {
                if vm.isDragTargeted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                        .overlay(
                            Label("Drop to add more images", systemImage: "plus.circle.fill")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isDragTargeted)
        }
    }

    private var dropHintBar: some View {
        HStack {
            Image(systemName: "plus.circle")
            Text("Drop more images to add them")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 8)
        .allowsHitTesting(false)
    }
}
