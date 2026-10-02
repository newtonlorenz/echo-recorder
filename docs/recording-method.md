# Recording Endel from an iPhone

Research date: 2026-10-02. This note separates documented behavior from device testing. No audio was recorded during this research.

## Findings that affect the choice

An initial device test captured Endel audio with the iPhone's built-in screen recorder while the phone was awake. That result applies to the tested phone/app combination; it does not establish locked-phone capture or multi-hour reliability.

Endel's published terms expressly restrict recording. Under “Our relationship with you; obligations of the user,” they prohibit: “Record, copy, edit, remix or otherwise use the sounds and sound environment created by the App other than listening to the sound environment as expressly set forth in these T&Cs.” Changing the capture method does not remove this stated restriction. This is a statement about the published terms, not a determination of their legal enforceability. [Endel terms article](https://endel.zendesk.com/hc/en-us/articles/360003558200-General-terms-and-conditions-for-Endel-app); [successfully fetched official article API](https://endel.zendesk.com/api/v2/help_center/en-us/articles/360003558200.json).

Apple documents routing audio directly from iOS/iPadOS devices into a Mac through Audio MIDI Setup. In Audio Devices, click **Enable** for the phone, then select it. Apple says a passcode unlock or trust approval may be requested. The Format controls expose sample rate and bit depth, with settings dependent on the device. [Apple: Set up audio devices](https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac).

Apple also states: “After you unlock your device, your accessory remains connected, even if your device is locked again.” Connect the cable and approve the connection while the phone is unlocked. The default setting is Automatically Allow When Unlocked; current settings are under Settings → Privacy & Security → Wired Accessories. An existing connection surviving relock is not proof that Endel's audio stream survives for hours. [Apple: Allow USB and other accessories](https://support.apple.com/en-us/111806).

Endel documents a Background Mode under its AirPlay button that allows playback alongside other sound sources, including calls. In that mode, Endel says its playback cannot be controlled from the lock screen. This confirms a supported background playback mode; it does not guarantee this Mac capture route or uninterrupted playback through every interruption. [Endel background playback article](https://endel.zendesk.com/hc/en-us/articles/8084345471900-How-to-listen-to-Endel-simultaneously-with-other-audio-applications); [successfully fetched official article API](https://endel.zendesk.com/api/v2/help_center/en-us/articles/8084345471900.json).

## Recommended technical route

For recording while the iPhone is locked, use a Mac companion that records the selected external audio input. First try the iPhone's direct digital input enabled in Audio MIDI Setup. Treat successful locked playback as an acceptance test, not a promise from this documentation.

If direct digital routing cannot sustain locked Endel playback, an alternative is the phone's ordinary wired headphone/DAC output into a **stereo line input** on a USB audio interface connected to the Mac. This is an engineering fallback proposal, not an Endel-validated configuration. It adds analog conversion, so it should not be described as bit-identical capture. A Mac built-in microphone is not the intended input.

Preserve the received sample rate and channel count. A lossless PCM file avoids an additional lossy encoding step; it cannot create source detail that was not supplied. Audio MIDI Setup's displayed format is evidence about the device input format, not a measurement of Endel's internal rendering precision. Apple documents reading/writing audio files through AVAudioPCMBuffer objects, with conversion between processing format and actual file format. [Apple: AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile); [fetched documentation data](https://developer.apple.com/tutorials/data/documentation/avfaudio/avaudiofile.json).

## Why screen recording is not the lock guarantee

Apple says screen recording saves a video and warns that some apps might not allow recording their content. The fetched guide does not provide a guarantee for recording through screen lock or multi-hour sessions, and it does not specify the recording's audio codec, sample rate, or bit depth. Do not infer those from a listening impression. [Apple: Take a screen recording](https://support.apple.com/guide/iphone/take-a-screen-recording-iph52f6e1987/ios).

ReplayKit's audioApp sample type is documented as audio originating from an app. This supports the idea of an app-audio capture extension, but the enum documentation does not guarantee delivery during phone lock. The successful built-in recording does not test a custom extension. [Apple: RPSampleBufferType.audioApp](https://developer.apple.com/documentation/replaykit/rpsamplebuffertype/audioapp); [fetched documentation data](https://developer.apple.com/tutorials/data/documentation/replaykit/rpsamplebuffertype/audioapp.json).

## Remaining acceptance tests

These hardware acceptance checks have not been performed for Echo:

1. Unlock and connect the actual iPhone; enable it in Audio MIDI Setup and select that input in the recorder. Confirm live levels while Endel plays.
2. Record a short sample while the phone is awake, then lock it for at least two minutes while capture continues. Stop and play back the entire file; verify that the locked portion contains Endel rather than silence.
3. Run an hour or the intended session length with the phone locked. Check duration, end-to-end audio, charging behavior, and recovery from cable disconnection. Keep the Mac awake during capture.
4. Record the phone model, iOS version, Endel version, cable/interface, Audio MIDI Setup input format, and observed outcome. Only describe locked endurance as verified after this test passes for that configuration.

## Endel-provided replay alternative

Endel says its app soundscapes are adaptive and personalized, while its albums on streaming services are prerecorded and static. Those releases provide an Endel-offered way to replay fixed soundscapes, but they do not reproduce an exact personalized phone session. [Endel comparison article](https://endel.zendesk.com/hc/en-us/articles/4940341254290-What-is-the-difference-between-the-soundscapes-in-the-app-and-Endel-albums-on-the-streaming-platforms); [successfully fetched official article API](https://endel.zendesk.com/api/v2/help_center/en-us/articles/4940341254290.json).

## Source access

Apple Support pages and Apple developer documentation data were fetched on 2026-10-02. Endel's own website links to its Zendesk support center. The support center's human article pages returned HTTP 403 during fetching; its public official Help Center API successfully supplied full articles, including the terms (updated_at 2025-10-07) and background guide (updated_at 2026-01-07). The [official article index](https://endel.zendesk.com/api/v2/help_center/en-us/articles.json?per_page=100) returned 72 articles with no next page. No separate official recording how-to was found in that index. The API access is why both human-facing and fetched API URLs are cited above.
