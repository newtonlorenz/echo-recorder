# Recording app audio from an iPhone

Research date: 2026-10-02. Documented behavior and hardware acceptance tests are separate. No audio was recorded during this research.

## Capture routes

Apple documents routing audio directly from iOS/iPadOS devices into a Mac through Audio MIDI Setup. In Audio Devices, click **Enable** for the phone, then select it. A passcode unlock or trust approval may be requested. Input format options depend on the device. [Apple: Set up audio devices](https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac).

Apple states that an accessory connected after unlocking remains connected when the device is locked again. Connect and approve the cable while the phone is unlocked. An existing connection surviving relock does not prove that a particular app's audio stream survives for hours. [Apple: Allow USB and other accessories](https://support.apple.com/en-us/111806).

Echo records the selected external audio input on the Mac. First try the iPhone's direct digital input in Audio MIDI Setup. Continued audio after phone lock must be verified on the actual phone, source app, and connection.

If direct routing is unavailable or becomes silent after lock, try the phone's wired headphone/DAC output into a **stereo line input** on a USB audio interface connected to the Mac. This adds analog conversion and is not bit-identical digital capture. A built-in room microphone is not the intended input.

Check the source app's background-playback behavior and interruption settings. Support varies by app, and neither an awake Mac nor a connected cable guarantees that the source keeps playing.

## Audio quality

Echo stores float32 PCM CAF at the input's nominal sample rate, up to stereo. Lossless storage avoids an additional lossy encoding step; it cannot add source detail. Audio MIDI Setup's format describes the input device, not the source app's internal rendering precision.

Apple documents reading and writing audio through AVAudioPCMBuffer objects, including conversion between processing and file formats. [Apple: AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile).

## Screen recording and phone lock

An initial device test captured app audio through the iPhone's built-in screen recorder while awake. This does not establish Echo's USB capture behavior, locked-phone capture, or multi-hour reliability.

Apple's screen-recording guide warns that some apps may not permit recording their content. It does not guarantee capture through phone lock or specify the audio codec, sample rate, or bit depth. [Apple: Take a screen recording](https://support.apple.com/guide/iphone/take-a-screen-recording-iph52f6e1987/ios).

ReplayKit documents app-originating audio samples, but that does not guarantee their delivery during phone lock. Echo uses a Mac audio input rather than a custom ReplayKit extension. [Apple: RPSampleBufferType.audioApp](https://developer.apple.com/documentation/replaykit/rpsamplebuffertype/audioapp).

## Hardware acceptance tests

These checks remain unverified for Echo:

1. Unlock and connect the iPhone; enable it in Audio MIDI Setup and select that input in Echo. Confirm live levels while permitted audio plays.
2. Record while awake, then lock the phone for at least two minutes. Stop and play the entire file; verify that the locked portion contains audio.
3. Test the intended session length with the phone locked. Check duration, end-to-end playback, charging, and recovery from cable disconnection. Keep the Mac powered and awake with its lid open.
4. Document phone model, iOS version, source-app version, cable/interface, input format, and results. Describe locked endurance as verified only after it passes for that configuration.

## Recording rights and sources

Record only audio you have permission to capture. Review the source app's terms and applicable restrictions; changing the capture route does not remove them.

Apple Support and developer documentation were reviewed on 2026-10-02. See [phone preparation](phone-preparation.md) for lock settings and interruption controls.
