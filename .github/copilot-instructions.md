# Echo Recorder development

Echo is a native macOS 14+ external-input recorder. Use Swift 5 language mode
and Apple frameworks only unless a dependency has an explicit justification.
See README.md, CONTRIBUTING.md, and docs/validation.md before making changes.

## Audio and UI

Keep recording in AVAudioRecorder with float32 PCM CAF and no duration limit.
Do not accumulate whole takes in memory or apply processing to recorded audio.
Allow compressed AAC M4A as an explicit export; never replace library originals.
Keep exports cancellable and finalize staging files before destination replacement.
InputMonitor uses a separate bounded AVAudioEngine tap for spectrum and peaks.
Monitoring failures must not stop an otherwise healthy take.
Protect active recordings during app updates, file export, and deletion.
Keep SwiftUI views focused on presentation; capture state belongs in Recorder.
Keep hardware limitations and error messages visible and accurate.
The Mac's idle-sleep assertion does not control iPhone lock or notifications.

## Verification and privacy

Run bash check.sh and bash build.sh. Use synthetic data for automated checks.
Actual device capture and phone-lock endurance require hardware acceptance tests.
Never commit personal audio, generated apps, backups, credentials, or local paths.
Update docs when behavior changes and distinguish evidence from assumptions.
Use focused pull requests and conventional commits.
