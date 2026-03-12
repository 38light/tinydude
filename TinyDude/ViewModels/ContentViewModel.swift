import Foundation
import AppKit
import SwiftUI

@MainActor
final class ContentViewModel: ObservableObject {

    // MARK: - Published state

    @Published var items: [ImageItem] = []
    @Published var settings = CompressionSettings()

    @Published var isProcessing  = false
    @Published var overallProgress: Double = 0
    @Published var completedCount: Int = 0
    @Published var totalCount: Int = 0

    @Published var showSummary = false
    @Published var results: [ProcessingResult] = []

    @Published var isDragTargeted = false

    // MARK: - Private

    private let processor = ImageProcessor()
    private var processingTask: Task<Void, Never>? = nil

    /// O(1) lookup for progress updates during batch processing
    private var itemIndex: [UUID: ImageItem] = [:]

    /// Max input file size: 500 MB
    private let maxFileSize: Int64 = 500 * 1024 * 1024

    // MARK: - Supported extensions

    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "avif",
        "heic", "heif", "tiff", "tif", "bmp", "gif"
    ]

    // MARK: - Queue management

    func addURLs(_ urls: [URL]) {
        let existing = Set(items.map(\.url))
        let filtered = urls.filter {
            supportedExtensions.contains($0.pathExtension.lowercased())
            && !existing.contains($0)
        }
        let newItems = filtered.map { ImageItem(url: $0) }

        // Reject files exceeding size limit
        for item in newItems where item.originalSize > maxFileSize {
            item.status = .failed(error: CompressionError.fileTooLarge(size: item.originalSize).localizedDescription)
        }

        items.append(contentsOf: newItems)
        rebuildIndex()
        updateEstimates()
    }

    func remove(_ item: ImageItem) {
        items.removeAll { $0.id == item.id }
        itemIndex.removeValue(forKey: item.id)
    }

    func clearAll() {
        guard !isProcessing else { return }
        items.removeAll()
        results.removeAll()
        itemIndex.removeAll()
        resetProgress()
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted || $0.isFailed }
        rebuildIndex()
    }

    func updateEstimates() {
        let fmt = settings.outputFormat
        let q   = settings.quality
        for item in items where item.isPending {
            item.estimatedOutputSize = processor.estimatedSize(
                originalSize: item.originalSize,
                format: fmt,
                quality: q
            )
        }
    }

    // MARK: - Output folder

    func browseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.outputFolder = url
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    // MARK: - Processing

    func startCompression() {
        guard !isProcessing, !pendingItems.isEmpty else { return }
        processingTask = Task { await runCompression() }
    }

    func cancelCompression() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false

        // Mark still-processing items back to pending
        for item in items where item.isProcessing {
            item.status = .pending
            item.progress = 0
        }
    }

    private var pendingItems: [ImageItem] {
        items.filter { $0.isPending || $0.isFailed }
    }

    private func resetProgress() {
        overallProgress = 0
        completedCount  = 0
        totalCount      = 0
    }

    private func rebuildIndex() {
        itemIndex = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private func runCompression() async {
        let pending = pendingItems
        guard !pending.isEmpty else { return }

        isProcessing   = true
        results        = []
        completedCount = 0
        totalCount     = pending.count
        overallProgress = 0

        // Reset failed items to pending before reprocessing
        for item in pending { item.status = .pending; item.progress = 0 }

        rebuildIndex()
        let settingsSnap = settings   // value-type copy — safe across tasks

        // Limit concurrency to CPU count to prevent memory exhaustion
        let maxConcurrency = max(2, ProcessInfo.processInfo.activeProcessorCount)

        await withTaskGroup(of: ProcessingResult?.self) { group in
            var iterator = pending.makeIterator()
            var inFlight = 0

            // Seed the group with up to maxConcurrency tasks
            while inFlight < maxConcurrency, let item = iterator.next() {
                addProcessingTask(to: &group, item: item, settings: settingsSnap)
                inFlight += 1
            }

            // As each task completes, add the next one
            for await _ in group {
                if let nextItem = iterator.next() {
                    addProcessingTask(to: &group, item: nextItem, settings: settingsSnap)
                }
            }
        }

        isProcessing    = false
        overallProgress = 1.0
        if !results.isEmpty { showSummary = true }
    }

    private func addProcessingTask(
        to group: inout TaskGroup<ProcessingResult?>,
        item: ImageItem,
        settings: CompressionSettings
    ) {
        let itemID = item.id

        group.addTask { [weak self] in
            guard let self else { return nil }

            // Check cancellation before starting
            guard !Task.isCancelled else { return nil }

            await MainActor.run { item.status = .processing }

            do {
                let result = try await self.processor.process(
                    item: item,
                    settings: settings,
                    onProgress: { progress in
                        Task { @MainActor [weak self] in
                            self?.itemIndex[itemID]?.progress = progress
                        }
                    }
                )

                await MainActor.run {
                    item.status   = .completed(savedBytes: result.savedBytes)
                    item.progress = 1.0
                    self.results.append(result)
                    self.completedCount += 1
                    self.overallProgress = Double(self.completedCount) / Double(self.totalCount)
                }
                return result
            } catch is CancellationError {
                await MainActor.run {
                    item.status   = .pending
                    item.progress = 0
                }
                return nil
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    item.status   = .failed(error: msg)
                    item.progress = 0
                    self.completedCount += 1
                    self.overallProgress = Double(self.completedCount) / Double(self.totalCount)
                }
                return nil
            }
        }
    }

    // MARK: - Summary helpers

    var totalOriginalSize: Int64 { results.reduce(0) { $0 + $1.originalSize } }
    var totalOutputSize:   Int64 { results.reduce(0) { $0 + $1.outputSize   } }
    var totalSaved:        Int64 { totalOriginalSize - totalOutputSize }
    var totalSavingPct: Double {
        guard totalOriginalSize > 0 else { return 0 }
        return Double(totalSaved) / Double(totalOriginalSize) * 100
    }
}
