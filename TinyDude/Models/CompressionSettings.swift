import Foundation

// MARK: - Resize Mode

enum ResizeMode: String, CaseIterable, Identifiable {
    case fit   = "Fit"
    case fill  = "Fill"
    case exact = "Exact"
    var id: String { rawValue }
}

// MARK: - Resize Options

struct ResizeOptions: Equatable {
    var enabled: Bool = false
    var maxWidth: Int = 1920
    var maxHeight: Int = 1080
    var maintainAspectRatio: Bool = true
    var mode: ResizeMode = .fit
}

// MARK: - Compression Settings (value type for thread safety)

struct CompressionSettings: Equatable {
    var quality: Double = 85          // 0–100
    var outputFormat: OutputFormat = .jpeg
    var stripMetadata: Bool = true
    var outputFolder: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    var filenameSuffix: String = "_tiny"
    var resize: ResizeOptions = ResizeOptions()

    /// Sanitized suffix — strips path separators and ".." to prevent path traversal
    var safeSuffix: String {
        let cleaned = filenameSuffix
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "..", with: "")
        return cleaned.isEmpty ? "_tiny" : cleaned
    }

    /// Output URL for a given input file
    func outputURL(for inputURL: URL) throws -> URL {
        guard let folder = outputFolder else {
            throw CompressionError.outputPathError
        }
        let base = inputURL.deletingPathExtension().lastPathComponent
        return folder
            .appendingPathComponent(base + safeSuffix)
            .appendingPathExtension(outputFormat.fileExtension)
    }

    /// Output URL with collision avoidance — appends -1, -2, etc. if file already exists
    func safeOutputURL(for inputURL: URL) throws -> URL {
        let baseURL = try outputURL(for: inputURL)
        let fm = FileManager.default

        if !fm.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        let dir = baseURL.deletingLastPathComponent()
        let name = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension

        for i in 1...999 {
            let candidate = dir
                .appendingPathComponent("\(name)-\(i)")
                .appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Extremely unlikely — 999 collisions
        return baseURL
    }
}

// MARK: - Errors

enum CompressionError: LocalizedError {
    case cannotLoadImage
    case cannotCreateDestination
    case compressionFailed
    case outputPathError
    case unsupportedFormat
    case fileTooLarge(size: Int64)

    var errorDescription: String? {
        switch self {
        case .cannotLoadImage:         return "Cannot load image"
        case .cannotCreateDestination: return "Cannot write to output folder — choose a different folder"
        case .compressionFailed:       return "Compression failed"
        case .outputPathError:         return "No output folder selected — choose an output folder"
        case .unsupportedFormat:       return "Format not supported for writing on this macOS version"
        case .fileTooLarge(let size):
            let mb = size / (1024 * 1024)
            return "File too large (\(mb) MB) — maximum is 500 MB"
        }
    }
}

// MARK: - Processing Result

struct ProcessingResult: Identifiable {
    let id = UUID()
    let inputURL: URL
    let outputURL: URL
    let originalSize: Int64
    let outputSize: Int64

    var savedBytes: Int64 { originalSize - outputSize }
    var savingPercent: Double {
        guard originalSize > 0 else { return 0 }
        return Double(savedBytes) / Double(originalSize) * 100
    }
}
