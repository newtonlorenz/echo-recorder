# Validation

Initial validation: 2026-10-02, Apple Silicon, macOS 26.6.1, Xcode 27.0.
These results describe the local build; CI results are available in GitHub Actions.

## Automated and build checks

- Standalone Swift build, ad hoc signing, and signature verification passed.
- Xcode Release build passed; the app launched successfully.
- Synthetic PCM CAF round trip preserved every sample.
- Sample rate, channels, frame count, and duration checks passed.
- Library exclusion of the active file passed with normalized file paths.
- Export and replacement export preserved exact original bytes.
- Export to the source path was a safe no-op.
- A generated 1 kHz tone appeared in the expected spectrum band.
- Stereo sample peaks and RMS matched expected dBFS.
- Opposite stereo phase did not cancel the spectrum.
- Full-scale, invalid-sample, and interleaved stereo checks passed.
- Silence produced no fabricated frequency activity.
- Nonfinite meter inputs produced finite display values.

Run `bash check.sh` to repeat the synthetic checks. They do not request audio
input permission or capture any microphone or phone audio.

## Hardware acceptance checks still required

Actual external-input capture, microphone permission, the iPhone USB spectrum
tap, recording after phone lock, and multi-hour endurance are unverified.
An initial report of successful iPhone screen-recorded app audio established
only capture while awake, not this app's USB or locked-phone behavior.

1. Connect and unlock the phone; enable its input in Audio MIDI Setup.
2. Select that input, play permitted audio, and confirm live levels.
3. Record while awake, then lock the phone for at least two minutes.
4. Stop and play the entire file; check that the locked portion contains audio.
5. Test the intended session length, charging, duration, and end-to-end playback.
6. Test disconnection recovery with a disposable take.
7. Document phone model, OS/app versions, cable/interface, input format, and results.

Keep the Mac powered with its lid open. Do not label locked-phone endurance
verified until these checks pass on the configuration concerned.
See [capture research](recording-method.md) and [phone preparation](phone-preparation.md).
