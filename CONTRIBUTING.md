# Contributing

Open an issue for a bug or proposed change, then send a focused pull request.
Include what changed, why, and how you checked it. Use conventional commit
messages such as `fix: preserve a take after input disconnection`.

Build with `bash build.sh` or the EchoRecorder Xcode scheme. Run
`bash check.sh` before submitting. Hardware changes also need a short recording
and playback test, including phone lock if that behavior is affected.
Share device and software versions with results, never private recordings.

## Architecture and conventions

- `Recorder` owns capture state, the library, playback, and sleep prevention.
- `AudioInputs` discovers Core Audio inputs and manages the default-input route.
- `AudioFiles` handles library metadata and original-byte exports.
- `InputMonitor` and `SpectrumAnalysis` provide bounded, read-only monitoring.
- SwiftUI views present that state. Keep UI changes separate from audio capture.
- Keep recordings streaming to disk and monitoring buffers bounded.
- Do not add gain, EQ, lossy encoding, or cloud uploads without an explicit design.
- Report capture and monitor failures clearly; protect active and partial takes.
- Use synthetic audio for automated checks. Never commit recordings or secrets.
- Describe hardware-dependent behavior as verified only with actual test evidence.

Changes are accepted under the project's [MIT license](LICENSE).
