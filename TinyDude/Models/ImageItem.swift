import Foundation
import AppKit

// MARK: - Status

enum ImageStatus: Equatable {
    case pending
    case processing
    case completed(savedBytes: Int64)
    case failed(error: String)

    static func == (lhs: ImageStatus, rhs: ImageStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending):       return true
        case (.processing, .processing): return true
        case (.completed(let a), .completed(let b)): return a == b
        case (.failed(let a), .failed(let b)):       return a == b
        default: return false
        }
    }
}

// MARK: - Image Item

@MainActor
final class ImageItem: ObservableObject, Identifiable {
    let id   = UUID()
    let url  : URL
    let name : String
    let originalSize: Int64

    @Published var thumbnail: NSImage?
    @Published var status: ImageStatus = .pending
    @Published var progress: Double = 0.0

    @Published var estimatedOutputSize: Int64? = nil

    init(url: URL) {
        self.url  = url
        self.name = url.lastPathComponent
        let rv = try? url.resourceValues(forKeys: [.fileSizeKey])
        self.originalSize = rv?.fileSize.map { Int64($0) } ?? 0
        Task { await loadThumbnail() }
    }

    // MARK: Computed helpers

    var isPending:    Bool { if case .pending    = status { return true }; return false }
    var isProcessing: Bool { if case .processing = status { return true }; return false }
    var isCompleted:  Bool { if case .completed  = status { return true }; return false }
    var isFailed:     Bool { if case .failed     = status { return true }; return false }

    var statusText: String {
        switch status {
        case .pending:                 return "Waiting"
        case .processing:              return "Processing…"
        case .completed(let saved):
            guard originalSize > 0 else { return "Done" }
            let pct = Int(Double(saved) / Double(originalSize) * 100)
            if pct < 0 { return "Grew \(-pct)%" }
            return "Saved \(pct)%"
        case .failed(let msg):         return "Error: \(msg)"
        }
    }

    var statusColor: NSColor {
        switch status {
        case .pending:     return .secondaryLabelColor
        case .processing:  return .systemBlue
        case .completed:   return .systemGreen
        case .failed:      return .systemRed
        }
    }

    // MARK: Thumbnail

    private func loadThumbnail() async {
        let url = self.url
        // Return CGImage (Sendable) from the detached task, convert on MainActor
        let cgThumb: CGImage? = await Task.detached(priority: .utility) {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 120,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg  = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            else { return nil }
            return cg
        }.value
        if let cg = cgThumb {
            self.thumbnail = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }
}

// MARK: - Formatters

private let sharedFileSizeFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return f
}()

extension Int64 {
    var formattedFileSize: String {
        sharedFileSizeFormatter.string(fromByteCount: self)
    }
}
