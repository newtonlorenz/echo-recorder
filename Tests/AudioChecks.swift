import Foundation
import AVFoundation

@main
struct AudioChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EchoChecks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Recording-test.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let count = 12345
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        for channel in 0..<2 {
            for frame in 0..<count {
                buffer.floatChannelData![channel][frame] = Float((frame + channel * 3) % 100) / 100 - 0.5
            }
        }
        do {
            let writer = try AVAudioFile(forWriting: source, settings: format.settings,
                commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            try writer.write(from: buffer)
        }
        let read = try AVAudioFile(forReading: source)
        precondition(read.length == Int64(count), "Frame count changed")
        precondition(read.fileFormat.sampleRate == 48000, "Sample rate changed")
        precondition(read.fileFormat.channelCount == 2, "Channel count changed")
        precondition((read.fileFormat.settings[AVLinearPCMIsFloatKey] as? Bool) == true, "PCM must be float")
        let decoded = AVAudioPCMBuffer(pcmFormat: read.processingFormat, frameCapacity: AVAudioFrameCount(count))!
        try read.read(into: decoded)
        for channel in 0..<2 {
            for frame in 0..<count {
                precondition(decoded.floatChannelData![channel][frame] == buffer.floatChannelData![channel][frame],
                    "A PCM sample changed")
            }
        }
        let listed = try AudioFiles.library(in: root, excluding: nil)
        precondition(listed.count == 1, "Library omitted audio")
        precondition(abs(listed[0].duration - Double(count) / 48000) < 0.00001, "Duration is incorrect")
        let filtered = try AudioFiles.library(in: root, excluding: source)
        precondition(filtered.isEmpty, "Active recordings must not be listed")
        let exported = root.appendingPathComponent("export.caf")
        try AudioFiles.export(source, to: exported)
        let originalBytes = try Data(contentsOf: source)
        var exportBytes = try Data(contentsOf: exported)
        precondition(originalBytes == exportBytes, "Export changed encoded bytes")
        try Data("old content".utf8).write(to: exported)
        try AudioFiles.export(source, to: exported)
        exportBytes = try Data(contentsOf: exported)
        precondition(originalBytes == exportBytes, "Replacement export failed")
        try AudioFiles.export(source, to: source)
        precondition(audioClock(3661) == "01:01:01")
        print("PASS: PCM samples preserved exactly; format, duration, library filtering and byte-for-byte export verified.")
    }
}
