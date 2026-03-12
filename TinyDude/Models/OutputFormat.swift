import Foundation
import ImageIO
import UniformTypeIdentifiers

enum OutputFormat: String, CaseIterable, Identifiable, Hashable {
    case jpeg = "JPEG"
    case png  = "PNG"
    case webp = "WebP"
    case avif = "AVIF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .webp: return "webp"
        case .avif: return "avif"
        }
    }

    /// UTType identifier used by ImageIO for encoding
    var utTypeIdentifier: String {
        switch self {
        case .jpeg: return "public.jpeg"
        case .png:  return "public.png"
        case .webp: return "org.webmproject.webp"
        case .avif: return "public.avif"
        }
    }

    var supportsLossy: Bool {
        switch self {
        case .jpeg, .webp, .avif: return true
        case .png: return false
        }
    }

    var systemImage: String {
        switch self {
        case .jpeg: return "photo"
        case .png:  return "photo.fill"
        case .webp: return "w.square"
        case .avif: return "a.square"
        }
    }

    /// Check if CGImageDestination can actually WRITE this format (not just read it)
    var isAvailable: Bool {
        guard let types = CGImageDestinationCopyTypeIdentifiers() as? [String] else {
            // Fallback: JPEG and PNG are always writable
            return self == .jpeg || self == .png
        }
        return types.contains(utTypeIdentifier)
    }
}
