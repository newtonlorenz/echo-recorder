# Preparing an iPhone for clean audio capture

Research date: 2026-10-02. No phone settings were changed and no audio was captured for this research.

## What the Mac app can control

The recorder can keep its **Mac** awake and record the selected input. It should not claim that this keeps the iPhone unlocked or silences other iPhone apps.

Apple's public iOS idle-timer property is explicitly “for the app.” It is not a remote global iPhone Auto-Lock setting. Its documentation also says properly configured audio playback/recording can continue when the screen turns off. No public USB control for changing the iPhone's global Auto-Lock setting is established by these sources. The practical control is on the iPhone, or a phone app's own foreground idle timer. [Apple: isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled); [fetched documentation data](https://developer.apple.com/tutorials/data/documentation/uikit/uiapplication/isidletimerdisabled.json).

The public INFocusStatusCenter API exposes authorization and retrieval of Focus status; its focusStatus property is read-only. It is not a public USB setter for the connected phone's Focus settings. [Apple: INFocusStatusCenter](https://developer.apple.com/documentation/intents/infocusstatuscenter); [fetched class data](https://developer.apple.com/tutorials/data/documentation/intents/infocusstatuscenter.json); [read-only property data](https://developer.apple.com/tutorials/data/documentation/intents/infocusstatuscenter/focusstatus.json).

There is a supported **system-sharing** alternative: with the same Apple Account and Settings → Focus → Share Across Devices enabled, Focus settings can be used across Apple devices. The user can turn on Focus through macOS controls; that is distinct from the recorder programmatically changing phone settings over USB. Focus filters do not sync through this switch. [Apple: Set up a Focus](https://support.apple.com/guide/iphone/set-up-a-focus-iphd6288a67f/ios).

The recorder receives an input stream, not separate source-app and notification tracks. Once sounds overlap in that stream, it cannot reliably remove one while preserving the other exactly. Apple documents that apps can mix audio with other active app sessions. Prevent unwanted sound at the phone rather than promising later separation. [Apple: mixWithOthers data](https://developer.apple.com/tutorials/data/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers.json).

## If the phone must stay unlocked

On the iPhone, go to Settings → Display & Brightness → Auto-Lock and select **Never**, if that option is available. Apple documents this settings path and explicitly discusses delaying or preventing Auto-Lock. Always-On Display is not a substitute: it displays a dimmed Lock Screen while the phone is locked. [Apple: Keep the iPhone display on longer](https://support.apple.com/guide/iphone/keep-the-iphone-display-on-longer-iph7117338a8/ios).

Turn off Low Power Mode before selecting an extended Auto-Lock setting. Apple says Low Power Mode sets Auto-Lock to **30 seconds**. On iPhone 15 and later the current path is Settings → Battery → Power Mode; on earlier models it is Settings → Battery. Adaptive Power can automatically enable Low Power Mode below 20% on supported devices. [Apple: Low Power Mode](https://support.apple.com/en-us/101604).

Keep the phone powered for long sessions. Restore the previous Auto-Lock setting afterward. Keeping the display on uses more power; it is unnecessary if the chosen capture path has already passed a locked-phone endurance test. Neither an awake Mac nor these settings establishes that source-app capture has passed that test.

## Reduce other sounds before recording

These are user-controlled preparation steps, not settings changed by the Mac recorder:

1. In Settings → Focus → Do Not Disturb, choose **Allow Notifications From** for People and Apps and leave both allowed lists empty. An empty **Silence Notifications From** list is not equivalent: it silences nobody. Review the calls option so no caller groups are permitted, and turn **Allow Repeated Calls** off. Apple defines repeated calls as two or more calls from the same person within three minutes.
2. Turn **Time Sensitive Notifications** off, and turn **Intelligent Breakthrough & Silencing** off where offered. Those features deliberately allow some notifications through. Enable Do Not Disturb in Control Center and keep it active for the session. Review schedules that might change Focus during a long recording.
3. Turn on the phone's Silent mode using its Ring/Silent switch, configured Action button, or Settings → Sounds & Haptics. Do not lower media volume to zero: Silent mode and playback volume have different purposes. Stop other audio apps before starting your source app; Silent mode does not silence audio apps or many games.
4. Check Clock alarms, wake-up alarms, and active timers. An alarm can sound despite Silent mode, Do Not Disturb, or connected headphones. Timers continue while another app is open or the phone sleeps; a **Stop Playing** timer can halt playback. Also check the source app's own shutoff timer or timed session before a long recording.

Sources for steps 1–2: [Apple: Allow or silence notifications for a Focus](https://support.apple.com/guide/iphone/allow-or-silence-notifications-for-a-focus-iph21d43af5b/ios), [Apple: Set up a Focus](https://support.apple.com/guide/iphone/set-up-a-focus-iphd6288a67f/ios). Sources for steps 3–4: [Apple: Silence iPhone](https://support.apple.com/guide/iphone/silence-iphone-iph81c7fd7d1/ios), [Apple: Set an alarm](https://support.apple.com/guide/iphone/set-an-alarm-iph2909d3a74/ios), [Apple: Set timers](https://support.apple.com/guide/iphone/set-timers-iph8241d6b2a/ios).

## Remaining exceptions

Do Not Disturb plus Silent mode is not a guarantee of no other sounds. Apple explicitly says authorized **Critical Alerts** ignore the mute switch and Do Not Disturb. Contacts with **Emergency Bypass** can be allowed through. Some government alerts cannot be disabled, depending on region; some emergency, camera, and Voice Memos sounds can play despite Silent mode. Alarms and other media remain additional exceptions. The recorder should describe preparation as reducing interruptions, not filtering every unwanted sound out of the capture.

Sources: [Apple: Critical alerts documentation data](https://developer.apple.com/tutorials/data/documentation/usernotifications/unauthorizationoptions/criticalalert.json), [Apple: Focus and Emergency Bypass](https://support.apple.com/guide/iphone/allow-or-silence-notifications-for-a-focus-iph21d43af5b/ios), [Apple: Government, Emergency, and Enhanced Safety Alerts](https://support.apple.com/en-us/102516), [Apple: Silence iPhone](https://support.apple.com/guide/iphone/silence-iphone-iph81c7fd7d1/ios).

## Optional offline session

Check whether your source app supports offline playback and prepare any required downloads before disconnecting. Confirm playback still works without network access; availability varies by app.

If the user can go without ordinary cellular calls and network access for the session, enable Airplane Mode and verify Wi-Fi stays off. Apple says Airplane Mode turns off cellular and Wi-Fi radios but leaves Bluetooth enabled by default; Wi-Fi and Bluetooth can be used while Airplane Mode is on. Turn Bluetooth off too if the session does not need it, to avoid unintended wireless routing. This is an optional tradeoff, not a requirement for recording. [Apple: Use Airplane Mode](https://support.apple.com/en-us/108785).

Offline operation reduces network-delivered interruptions but does not disable local alarms, timers, or other app sounds. Verify the source app and the chosen wired input still produce audio after preparing the phone; Focus/airplane preparation is not an endurance test. Restore the user's normal connectivity, Focus, and Auto-Lock settings after the session.

## Source access and scope

Cited Apple pages and documentation data were fetched on 2026-10-02. iPhone menus vary with iOS version and model. The app’s precise input format and its long-running behavior are separate from these phone-preparation findings. See [recording-method.md](recording-method.md) for capture feasibility and the untested locked-phone endurance checks.
