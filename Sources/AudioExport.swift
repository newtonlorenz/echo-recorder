import Foundation
import AVFoundation

enum AudioExportFormat: String, CaseIterable, Sendable {
    case original, aac
    var title: String { self == .original ? "Original · Lossless CAF" : "Compressed · M4A (AAC)" }
    var fileExtension: String { self == .original ? "caf" : "m4a" }
}

final class AudioExportJob: @unchecked Sendable {
    let source: URL
    let destination: URL
    let format: AudioExportFormat
    private let lock = NSLock()
    private var cancelled = false
    private var fraction: Double = 0
    private var session: AVAssetExportSession?

    init(source: URL, destination: URL, format: AudioExportFormat) {
        self.source = source
        self.destination = destination
        self.format = format
    }

    var progress: Double {
        lock.lock()
        let value = fraction
        let active = session
        lock.unlock()
        return value == 1 ? 1 : min(0.99, max(value, Double(active?.progress ?? 0)))
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let active = session
        lock.unlock()
        active?.cancelExport()
    }

    private func checkCancellation() throws {
        lock.lock()
        let stopped = cancelled
        lock.unlock()
        if stopped { throw CancellationError() }
    }

    private func setProgress(_ value: Double) {
        lock.lock()
        fraction = value
        lock.unlock()
    }

    func run() async throws {
        try checkCancellation()
        let sourcePath = source.resolvingSymlinksInPath().standardizedFileURL.path
        let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL.path
        guard sourcePath != destinationPath else {
            if format == .original { setProgress(1); return }
            throw failure("Choose a different destination. The original recording cannot be replaced by compressed audio.")
        }
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".echo-\(UUID().uuidString).\(format.fileExtension)")
        defer { try? FileManager.default.removeItem(at: staging) }
        if format == .original {
            try await Task.detached(priority: .utility) { try self.copyOriginal(to: staging) }.value
        } else {
            try await encodeAAC(to: staging)
        }
        try checkCancellation()
        try AudioFiles.installExport(staging, at: destination)
        setProgress(1)
    }

    private func copyOriginal(to staging: URL) throws {
        let size = (try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        guard FileManager.default.createFile(atPath: staging.path, contents: nil) else {
            throw failure("The export file could not be created.")
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: staging)
        defer { try? output.close() }
        var written = 0
        while true {
            try checkCancellation()
            guard let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
            try output.write(contentsOf: data)
            written += data.count
            setProgress(min(0.99, Double(written) / Double(max(1, size))))
        }
        try output.synchronize()
    }

    private func encodeAAC(to staging: URL) async throws {
        guard let next = AVAssetExportSession(asset: AVURLAsset(url: source),
            presetName: AVAssetExportPresetAppleM4A) else {
            throw failure("This recording cannot be exported as M4A.")
        }
        next.outputURL = staging
        next.outputFileType = .m4a
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startExport(next, continuation: continuation)
        }
    }

    private func startExport(_ next: AVAssetExportSession, continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        session = next
        next.exportAsynchronously { [self] in
            continuation.resume(with: completionResult())
        }
        lock.unlock()
    }

    private func completionResult() -> Result<Void, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let session else { return .failure(failure("Compressed export could not start.")) }
        switch session.status {
        case .completed: return .success(())
        case .cancelled: return .failure(CancellationError())
        default: return .failure(session.error ?? failure("Compressed export failed."))
        }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "EchoExport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
