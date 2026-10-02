import SwiftUI
import AppKit

struct RecorderView: View {
    @Bindable var model: Recorder
    @State private var showGuide = false
    @State private var showPhoneGuide = false
    @State private var deleting: SavedAudio?
    private let accent = Color(red: 0.72, green: 0.85, blue: 0.38)

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Echo").font(.system(size: 34, weight: .bold))
                    Text("Keep the sound.").font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Connection guide", systemImage: "cable.connector") { showGuide.toggle() }
            }
            if showGuide { guide }
            HStack(spacing: 16) {
                Picker("Audio input", selection: $model.selectedID) {
                    Text("Choose an input").tag(UInt32(0))
                    ForEach(model.inputs) { input in
                        Text(input.name + (input.builtIn ? " (room microphone)" : "")).tag(input.id)
                    }
                }.disabled(model.recording || model.starting)
                Button("Refresh", systemImage: "arrow.clockwise") { model.refreshInputs() }
                    .disabled(model.recording || model.starting)
            }
            Text(model.recording ? model.inputName : inputDescription)
                .font(.caption).foregroundStyle(.secondary)
            recordingCard
            MonitoringView(model: model)
            DisclosureGroup("Prepare the iPhone: locking and interruptions", isExpanded: $showPhoneGuide) {
                phoneGuide.padding(.top, 10)
            }.font(.callout)
            HStack {
                Text("Your recordings").font(.title2.bold())
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: model.freeBytes, countStyle: .file) + " free")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Show folder", systemImage: "folder") { NSWorkspace.shared.open(model.folder) }
            }
            if model.library.isEmpty {
                ContentUnavailableView("Your sound, on hand", systemImage: "waveform",
                    description: Text("Recordings stay on this Mac. Play or export them anytime."))
                    .frame(minHeight: 130)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.library) { audio in audioRow(audio) }
                }
            }
            Text("Keep the Mac powered with the lid open. Echo prevents idle system sleep during recording; closing the lid can still stop capture.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        }.frame(minWidth: 720, minHeight: 820).tint(accent)
        .alert("Echo Recorder", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert("Delete this recording?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let deleting { model.delete(deleting) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("This removes the audio file from this Mac.") }
        .task {
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var inputDescription: String {
        guard let input = model.selected else { return "Connect the iPhone or a stereo audio interface." }
        if input.builtIn { return "Choose a wired input. The built-in microphone records room sound." }
        return String(format: "%.1f kHz · %d channels · Lossless PCM", input.rate / 1000, min(2, input.channels))
    }

    private var recordingCard: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.recording ? "Recording" : "Ready to record")
                    .font(.headline).foregroundStyle(model.recording ? accent : Color.secondary)
                Text(audioClock(model.elapsed)).font(.system(size: 44, weight: .light, design: .monospaced))
                ProgressView(value: model.recording ? max(0, min(1, Double(model.level + 60) / 60)) : 0)
                    .tint(accent).accessibilityLabel("Audio input level")
                Text(model.recording && model.elapsed > 10 && model.level < -70
                     ? "No signal yet. Check the source app and the selected input."
                     : "Saved directly to disk. No recording time limit.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if model.recording { model.stop() } else { Task { await model.start() } }
            } label: {
                Label(model.recording ? "Stop & save" : "Record",
                    systemImage: model.recording ? "stop.fill" : "record.circle")
                    .font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
            .disabled(model.starting || (!model.recording && (model.selected == nil || model.selected?.builtIn == true)))
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(24).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
    }

    private func audioRow(_ audio: SavedAudio) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Button { model.toggle(audio) } label: {
                    Image(systemName: model.playingURL == audio.url && model.playing ? "pause.fill" : "play.fill")
                        .frame(width: 32, height: 32)
                }.disabled(model.recording).help("Play or pause recording")
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.title).font(.headline).lineLimit(1)
                    Text("\(audioClock(audio.duration)) · \(Int(audio.rate)) Hz · \(audio.channels) ch · PCM")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export", systemImage: "square.and.arrow.up") { model.export(audio) }
                    .disabled(model.recording)
                Button { deleting = audio } label: { Image(systemName: "trash") }
                    .help("Delete recording")
            }
            if model.playingURL == audio.url {
                Slider(value: Binding(get: { model.position }, set: { model.seek($0) }),
                    in: 0...max(0.01, audio.duration)).accessibilityLabel("Playback position")
            }
        }.padding(14).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var phoneGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phone locking")
                .font(.headline)
            Text("Echo keeps the Mac awake, not the iPhone. If you want the phone display to stay on, set Settings → Display & Brightness → Auto-Lock → Never. Low Power Mode must be off.")
            Text("Leaving the phone locked is fine only after your USB audio test succeeds.")
            Text("Quiet recording")
                .font(.headline).padding(.top, 4)
            Text("Use a Do Not Disturb Focus with no allowed apps or people. Disable allowed calls, repeated calls, Time Sensitive notifications and Intelligent Breakthrough if available. Use Silent mode, and stop alarms, timers and the source app’s sleep timer.")
            Text("If Share Across Devices is enabled, switching on Do Not Disturb in Mac Control Center can apply it to the iPhone too. Echo does not switch these phone settings automatically.")
            Text("If your source app supports offline playback, you can use Airplane Mode with Wi-Fi off and Bluetooth off if unnecessary. Test playback first. Calls and messages will not arrive normally.")
            Text("Focus and Silent mode cannot guarantee silence: critical alerts, emergency exceptions, alarms and other media may still sound. Echo records the mixed iPhone input and cannot reliably remove overlapping sounds.")
                .foregroundStyle(.secondary)
            Link("Apple’s Focus setup guide", destination: URL(string: "https://support.apple.com/guide/iphone/set-up-a-focus-iphd6288a67f/ios")!)
        }.font(.callout).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start with your USB cable").font(.headline)
            Text("1. Connect and trust the iPhone while it is unlocked.")
            Text("2. In Audio MIDI Setup, select the iPhone and click Enable if it appears. Refresh the inputs here and choose it.")
            Text("3. Play audio in your source app and record one minute. Lock the phone midway, then stop and listen to the saved audio.")
            Text("If USB audio is unavailable or stops when locked, use the iPhone’s headphone adapter into a stereo line-input USB audio interface.")
                .foregroundStyle(.secondary)
            Button("Open Audio MIDI Setup") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app"))
            }
        }.font(.callout).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

@MainActor
final class EchoDelegate: NSObject, NSApplicationDelegate {
    let recorder = Recorder()
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        recorder.stop()
        return .terminateNow
    }
}

@main
struct EchoApp: App {
    @NSApplicationDelegateAdaptor(EchoDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { RecorderView(model: delegate.recorder) }
            .defaultSize(width: 820, height: 960)
    }
}
