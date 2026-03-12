import Foundation
import CoreImage
import ImageIO
import AppKit
import UniformTypeIdentifiers

// MARK: - Image Processor Actor

/// Runs on its own executor; safe to call from any async context.
actor ImageProcessor {

    // Reuse a single CIContext across all images — creating one is expensive
    // (allocates GPU/Metal resources). Thread-safe because we're inside an actor.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public API

    func process(
        item: ImageItem,
        settings: CompressionSettings,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> ProcessingResult {

        let url = item.url
        onProgress(0.05)

        // Check cancellation before starting expensive work
        try Task.checkCancellation()

        // 0. Verify format can be written
        guard settings.outputFormat.isAvailable else {
            throw CompressionError.unsupportedFormat
        }

        // 1. Load source image
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CompressionError.cannotLoadImage
        }
        guard let rawCGImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CompressionError.cannotLoadImage
        }

        // 1b. Apply EXIF orientation to pixel data so portrait stays portrait.
        //     CGImageSourceCreateImageAtIndex returns raw pixels (often landscape
        //     for phone photos) with a separate EXIF orientation tag. We bake the
        //     rotation into the actual pixels here, then strip the tag from metadata.
        let cgImage: CGImage
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32,
           orientationValue != 1, // 1 = "Up" = no rotation needed
           let ciOrientation = CGImagePropertyOrientation(rawValue: orientationValue) {
            let oriented = CIImage(cgImage: rawCGImage).oriented(ciOrientation)
            guard let corrected = ciContext.createCGImage(oriented, from: oriented.extent) else {
                throw CompressionError.compressionFailed
            }
            cgImage = corrected
        } else {
            cgImage = rawCGImage
        }
        onProgress(0.25)

        // Check cancellation after decode
        try Task.checkCancellation()

        // 2. Resize if needed
        let resized = settings.resize.enabled
            ? resizeImage(cgImage, options: settings.resize)
            : cgImage
        onProgress(0.50)

        // Check cancellation after resize
        try Task.checkCancellation()

        // 3. Determine output path (with collision avoidance)
        let outputURL = try settings.safeOutputURL(for: url)

        // Ensure output directory exists
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw CompressionError.cannotCreateDestination
        }
        onProgress(0.60)

        // 4. Copy original metadata if requested (but always remove orientation
        //    tag since we already baked it into the pixel data above)
        var metadata: [CFString: Any]? = nil
        if !settings.stripMetadata {
            if var props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                // Remove orientation — already applied to pixels
                props.removeValue(forKey: kCGImagePropertyOrientation)
                // Also remove TIFF orientation if present
                if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                    tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation)
                    props[kCGImagePropertyTIFFDictionary] = tiff
                }
                metadata = props
            }
        }

        // Final cancellation check before writing
        try Task.checkCancellation()

        // 5. Encode & write
        try writeImage(resized, to: outputURL, settings: settings, metadata: metadata)
        onProgress(0.90)

        // 6. Measure sizes
        let originalSize = fileSize(of: url)
        let outputSize   = fileSize(of: outputURL)
        onProgress(1.00)

        return ProcessingResult(
            inputURL: url,
            outputURL: outputURL,
            originalSize: originalSize,
            outputSize: outputSize
        )
    }

    // MARK: - Resize

    private func resizeImage(_ image: CGImage, options: ResizeOptions) -> CGImage {
        let srcW = image.width
        let srcH = image.height
        var dstW = options.maxWidth
        var dstH = options.maxHeight

        if options.maintainAspectRatio {
            let wratio = Double(options.maxWidth)  / Double(srcW)
            let hratio = Double(options.maxHeight) / Double(srcH)
            let ratio: Double
            switch options.mode {
            case .fit:   ratio = min(wratio, hratio)
            case .fill:  ratio = max(wratio, hratio)
            case .exact: ratio = wratio   // width takes precedence
            }
            dstW = max(1, Int(Double(srcW) * ratio))
            dstH = max(1, Int(Double(srcH) * ratio))
        }

        // Skip resize if dimensions unchanged
        if dstW == srcW && dstH == srcH { return image }

        // Use Core Image for high-quality Lanczos resizing (reuse actor's CIContext)
        let ciImage = CIImage(cgImage: image)
        let scaleX  = CGFloat(dstW) / CGFloat(srcW)
        let scaleY  = CGFloat(dstH) / CGFloat(srcH)
        let scaled  = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let out = ciContext.createCGImage(scaled, from: scaled.extent) {
            return out
        }

        // Fallback: CGContext draw
        let cs = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = image.bitmapInfo
        guard let ctx = CGContext(data: nil, width: dstW, height: dstH,
                                  bitsPerComponent: image.bitsPerComponent,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: bitmapInfo.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))
        return ctx.makeImage() ?? image
    }

    // MARK: - Write / Encode

    private func writeImage(
        _ image: CGImage,
        to url: URL,
        settings: CompressionSettings,
        metadata: [CFString: Any]?
    ) throws {
        guard settings.outputFormat.isAvailable else {
            throw CompressionError.unsupportedFormat
        }

        let uti = settings.outputFormat.utTypeIdentifier as CFString

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
            throw CompressionError.cannotCreateDestination
        }

        var props: [CFString: Any] = [:]

        // Quality (only for lossy formats)
        if settings.outputFormat.supportsLossy {
            let q = settings.quality / 100.0
            props[kCGImageDestinationLossyCompressionQuality] = q
        }

        // Metadata passthrough
        if let meta = metadata {
            // Merge, but never include GPS if stripping
            for (k, v) in meta {
                if k == kCGImagePropertyGPSDictionary && settings.stripMetadata { continue }
                props[k] = v
            }
        }

        CGImageDestinationAddImage(destination, image, props as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.compressionFailed
        }
    }

    // MARK: - Helpers

    private func fileSize(of url: URL) -> Int64 {
        let rv = try? url.resourceValues(forKeys: [.fileSizeKey])
        return rv?.fileSize.map { Int64($0) } ?? 0
    }
}

// MARK: - Estimated output size (fast, cheap heuristic)

extension ImageProcessor {
    nonisolated func estimatedSize(
        originalSize: Int64,
        format: OutputFormat,
        quality: Double
    ) -> Int64 {
        guard originalSize > 0 else { return 0 }
        let q = quality / 100.0

        let ratio: Double
        switch format {
        case .jpeg: ratio = 0.05 + q * 0.70   // 5% → 75%
        case .png:  ratio = 0.80               // roughly same (lossless)
        case .webp: ratio = 0.04 + q * 0.55
        case .avif: ratio = 0.03 + q * 0.40
        }
        return Int64(Double(originalSize) * ratio)
    }
}
