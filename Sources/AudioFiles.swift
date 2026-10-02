import Foundation
import AVFoundation

struct SavedAudio: Identifiable {
    let url: URL
    let duration: Double
    let rate: Double
    let channels: Int
    var id: URL { url }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

enum AudioFiles {
    static func library(in folder: URL, excluding active: URL?) throws -> [SavedAudio] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension.lowercased() == "caf" && $0.resolvingSymlinksInPath().standardizedFileURL.path != active?.resolvingSymlinksInPath().standardizedFileURL.path }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .compactMap { url in
                guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
                return SavedAudio(url: url, duration: Double(file.length) / file.processingFormat.sampleRate,
                    rate: file.fileFormat.sampleRate, channels: Int(file.fileFormat.channelCount))
            }
    }

    // Copy the original bytes. Never transcode or load the recording into RAM.
    static func export(_ source: URL, to destination: URL) throws {
        guard source.resolvingSymlinksInPath().standardizedFileURL.path != destination.resolvingSymlinksInPath().standardizedFileURL.path else { return }
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".echo-\(UUID().uuidString).caf")
        do {
            try FileManager.default.copyItem(at: source, to: staging)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
                try FileManager.default.moveItem(at: staging, to: destination)
            }
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }
}

func audioClock(_ time: Double) -> String {
    let seconds = max(0, Int(time))
    return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
}
