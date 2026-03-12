import SwiftUI
import AppKit

struct ImageRowView: View {
    @ObservedObject var item: ImageItem
    @EnvironmentObject var vm: ContentViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Label(item.originalSize.formattedFileSize, systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let est = item.estimatedOutputSize, item.isPending {
                        Label("~\(est.formattedFileSize)", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if case .completed(let saved) = item.status {
                        let outSize = item.originalSize - saved
                        Label(outSize.formattedFileSize, systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                // Progress or status
                if item.isProcessing {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                } else {
                    HStack(spacing: 4) {
                        statusIcon
                        Text(item.statusText)
                            .font(.caption)
                            .foregroundColor(Color(item.statusColor))
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 6) {
                if case .completed = item.status {
                    Button {
                        if let result = vm.results.first(where: { $0.inputURL == item.url }) {
                            vm.revealInFinder(result.outputURL)
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reveal in Finder")
                    .accessibilityLabel("Reveal in Finder")
                }

                Button {
                    vm.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.name), \(item.originalSize.formattedFileSize), \(item.statusText)")
    }

    // MARK: - Sub-views

    private var thumbnailView: some View {
        Group {
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .processing:
            EmptyView()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
    }
}
