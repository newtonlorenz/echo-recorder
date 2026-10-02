# Echo Recorder

A small native macOS app for recording an external audio input, saving long
sessions without lossy encoding, and playing them back later. Connect an iPhone
over USB or use a stereo line-input audio interface.

## Features

- Float32 PCM CAF recordings at the input's nominal sample rate, up to stereo.
- No application duration limit; recordings stream to disk.
- Live 14-band spectrum, stereo sample-peak meters, peak hold, and clipping warnings.
- Playback, seeking, original-byte export, and a local recording library.
- Keeps the Mac awake during recording; stops on detected disconnection, input
  change, low storage, or capture error, preserving the captured portion.
- Phone-preparation guide for Auto-Lock, Focus, and other sound interruptions.
- No third-party dependencies, accounts, telemetry, or cloud recording storage.

## Requirements and build

macOS 14 or later, Xcode with its command-line tools, and an external audio input.
The project uses Swift 5 language mode, SwiftUI, AVFAudio, Core Audio, Accelerate,
and IOKit. Local builds use ad hoc signing; no paid developer account is needed.
Distributed builds are not notarized.

Open `EchoRecorder.xcodeproj`, select the **EchoRecorder** scheme, and Run.
Alternatively, from a checkout:

```sh
bash build.sh
open "build/Echo Recorder.app"
```

Allow Microphone access when prompted: macOS requires it for USB audio inputs
too. Built-in room microphones are excluded as recording sources.

## Connect an iPhone

1. Connect and unlock the iPhone; approve **Trust** if requested.
2. Open **Audio MIDI Setup** on the Mac. Select the iPhone and click **Enable**.
3. Refresh Echo's input list and select the iPhone.
4. Play audio you have permission to record, start recording, and check live levels.
5. Make a short test, locking the phone halfway through. Stop and listen to the
   entire file, including the locked portion.
6. Test the intended session length before relying on hours of capture.

USB availability and continued audio after phone lock depend on the actual
phone, software, and connection. Locked-phone and multi-hour capture have not
been verified for this project. See [capture research](docs/recording-method.md).

If USB routing is unavailable or goes silent after lock, try the iPhone's
headphone/DAC adapter → stereo cable → **stereo line input** on a USB audio
interface → Mac. This adds analog conversion. Most Mac headphone jacks are
outputs, not stereo line inputs.

## Phone lock and interruptions

Echo prevents idle sleep on the **Mac** during recording. Keep it powered with
the lid open. Forced sleep, closing the lid, shutdown, or source-app interruptions
can stop capture.

Echo cannot remotely disable the iPhone's global Auto-Lock or silence its other
apps. Use the in-app guide or [phone preparation](docs/phone-preparation.md) to
configure Do Not Disturb, Silent mode, alarms, timers, and optional offline use.
These settings reduce interruptions; they do not guarantee that every unwanted
sound is suppressed. Mixed sounds cannot reliably be separated afterward.

## Audio quality and storage

CAF avoids WAV's conventional 4 GB file limit. At 48 kHz stereo float32, allow
about **1.38 GB per hour** plus free space. Files stay in
`~/Library/Application Support/EchoRecorder`; **Show folder** opens the library.
Export copies the original file bytes.

Lossless storage avoids an additional lossy encoding step. It cannot improve
the source audio or undo an interface's conversion. The spectrum is a display,
not an audio equalizer: it applies no EQ or gain. Full-scale warnings indicate
possible clipping; meters cannot certify source quality or detect every kind
of existing distortion.

Choosing an input temporarily changes the Mac's system default input. Echo
restores the previous input afterward unless it was changed during capture.
Spectrum monitoring uses a separate, bounded input tap. If that monitor fails,
Echo reports the issue and retains OS peak meters while recording continues.

## Development and tests

```sh
bash check.sh
bash build.sh
```

Checks use synthetic audio only: PCM samples and metadata, duration, library
exclusion, byte-exact exports, spectrum calibration, stereo phase, clipping,
invalid samples, and silence. They do not record phone or microphone audio.
See [validation and device checks](docs/validation.md). GitHub Actions builds
the app and runs these checks on macOS.

`Sources/` contains the app and audio code; `Tests/` contains standalone checks;
`docs/` contains sourced capture guidance and validation notes.
`EchoRecorder.xcodeproj/` provides the native Xcode project.

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture, coding conventions,
and the pull-request workflow.

## Recording rights

Use Echo for audio you have permission to record. Check the source app's terms
and any applicable recording restrictions. Echo is a general-purpose recorder.

## License

[MIT](LICENSE). Copyright © 2026 Dan Graetzer.
