import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject var vm: ContentViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Output Format
                sectionHeader("Output Format")
                formatPicker

                Divider()

                // Quality
                sectionHeader("Quality")
                qualitySlider

                Divider()

                // Resize
                sectionHeader("Resize")
                resizeSection

                Divider()

                // Metadata
                sectionHeader("Metadata")
                Toggle("Strip metadata (GPS, EXIF, etc.)", isOn: $vm.settings.stripMetadata)
                    .toggleStyle(.checkbox)
                    .onChange(of: vm.settings) { _ in vm.updateEstimates() }

                Divider()

                // Output Destination
                sectionHeader("Output Destination")
                outputSection

                Divider()

                // Filename
                sectionHeader("Filename Suffix")
                HStack {
                    TextField("e.g. _tiny", text: $vm.settings.filenameSuffix)
                        .textFieldStyle(.roundedBorder)
                    Text(".\(vm.settings.outputFormat.fileExtension)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        VStack(spacing: 6) {
            ForEach(OutputFormat.allCases) { fmt in
                formatRow(fmt)
            }
        }
    }

    private func formatRow(_ fmt: OutputFormat) -> some View {
        Button {
            vm.settings.outputFormat = fmt
            vm.updateEstimates()
        } label: {
            HStack {
                Image(systemName: fmt.systemImage)
                    .frame(width: 20)
                Text(fmt.rawValue)
                Spacer()
                if !fmt.isAvailable {
                    Text("Not supported")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if vm.settings.outputFormat == fmt {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                vm.settings.outputFormat == fmt
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!fmt.isAvailable)
        .opacity(fmt.isAvailable ? 1.0 : 0.5)
        .accessibilityLabel("\(fmt.rawValue) format\(vm.settings.outputFormat == fmt ? ", selected" : "")")
        .accessibilityHint(fmt.isAvailable ? "Select \(fmt.rawValue) as output format" : "Not supported on this macOS version")
    }

    // MARK: - Quality Slider

    private var qualitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quality")
                Spacer()
                Text("\(Int(vm.settings.quality))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $vm.settings.quality,
                in: 1...100,
                step: 1
            ) {
                Text("Quality")
            } onEditingChanged: { _ in
                vm.updateEstimates()
            }
            .tint(.accentColor)
            .accessibilityValue("\(Int(vm.settings.quality)) percent")
            .accessibilityHint("Adjust compression quality from 1 to 100")

            HStack {
                Text("Smaller")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Larger")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !vm.settings.outputFormat.supportsLossy {
                Text("PNG is lossless; quality setting has no effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Resize Section

    @ViewBuilder
    private var resizeSection: some View {
        Toggle("Enable resize", isOn: $vm.settings.resize.enabled)
            .toggleStyle(.checkbox)

        if vm.settings.resize.enabled {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    labeledField("Width", value: $vm.settings.resize.maxWidth)
                    Text("×")
                        .foregroundStyle(.secondary)
                    labeledField("Height", value: $vm.settings.resize.maxHeight)
                }

                Toggle("Maintain aspect ratio", isOn: $vm.settings.resize.maintainAspectRatio)
                    .toggleStyle(.checkbox)

                if vm.settings.resize.maintainAspectRatio {
                    Picker("Mode", selection: $vm.settings.resize.mode) {
                        ForEach(ResizeMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.leading, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func labeledField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", value: value, formatter: NumberFormatter.pixels)
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
        }
    }

    // MARK: - Output Section

    @ViewBuilder
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let folder = vm.settings.outputFolder {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(folder.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
            } else {
                Text("No folder selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Choose Folder…") { vm.browseOutputFolder() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Open folder picker to choose where compressed images are saved")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - NumberFormatter

private extension NumberFormatter {
    static let pixels: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimum = 1
        f.maximum = 99999
        return f
    }()
}
