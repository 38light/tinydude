import SwiftUI

struct CompletionSummaryView: View {
    @EnvironmentObject var vm: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Stats
            statsGrid

            Divider()

            // File list
            fileList

            Divider()

            // Actions
            actionBar
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Compression Complete")
                    .font(.title2.weight(.semibold))
                Text("\(vm.results.count) image\(vm.results.count == 1 ? "" : "s") processed")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCard(
                icon: "arrow.down.circle.fill",
                iconColor: .blue,
                title: "Original",
                value: vm.totalOriginalSize.formattedFileSize
            )
            Divider()
            statCard(
                icon: "arrow.up.circle.fill",
                iconColor: .green,
                title: "Compressed",
                value: vm.totalOutputSize.formattedFileSize
            )
            Divider()
            statCard(
                icon: "bolt.fill",
                iconColor: .orange,
                title: "Saved",
                value: "\(vm.totalSaved.formattedFileSize) (\(Int(vm.totalSavingPct))%)"
            )
        }
        .padding(.vertical, 4)
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(vm.results) { result in
                    resultRow(result)
                }
            }
            .padding(12)
        }
    }

    private func resultRow(_ result: ProcessingResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.outputURL.lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(result.originalSize.formattedFileSize) → \(result.outputSize.formattedFileSize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Saving badge
            Text(result.savedBytes >= 0 ? "-\(Int(result.savingPercent))%" : "+\(Int(-result.savingPercent))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(result.savedBytes > 0 ? .green : .orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (result.savedBytes > 0 ? Color.green : Color.orange).opacity(0.12),
                    in: Capsule()
                )

            // Reveal button
            Button {
                vm.revealInFinder(result.outputURL)
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal \(result.outputURL.lastPathComponent) in Finder")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(result.outputURL.lastPathComponent), \(result.originalSize.formattedFileSize) to \(result.outputSize.formattedFileSize), \(result.savedBytes >= 0 ? "saved" : "grew") \(Int(abs(result.savingPercent))) percent")
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Button("Reveal All in Finder") {
                if let first = vm.results.first {
                    vm.revealInFinder(first.outputURL)
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Compress More") {
                vm.clearCompleted()
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }
}
