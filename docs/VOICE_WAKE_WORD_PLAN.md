# OpenClicky Wake Word Voice Plan

Date: 2026-05-31

## Goal

Let OpenClicky run in a hands-free listening mode where the microphone can stay armed, but normal voice routing only starts after the user says `Hey Clicky`. The existing activation shortcut should become a toggle for this hands-free mode, while the current push-to-talk behavior can remain available as a fallback.

## Current code path

- `GlobalPushToTalkShortcutMonitor.swift` listens for the current activation shortcut and emits `.pressed` / `.released` transitions.
- `CompanionManager.handleShortcutTransition(_:)` turns those transitions into either:
  - Realtime bidirectional voice capture through `startBidirectionalRealtimeVoiceCapture(source:)` / `finishBidirectionalRealtimeVoiceCaptureIfNeeded(source:)`, or
  - streaming transcription through `BuddyDictationManager.startPushToTalkFromKeyboardShortcut(...)`.
- The Realtime path currently disables server turn detection by sending `turn_detection: null`, captures mic audio locally, commits the audio buffer on key release, then lets the app route the final transcript before asking the model to speak.
- The cursor/notch state already has `idle`, `listening`, `processing`, and `responding`, so hands-free mode does not need a new visual system; it needs a distinct “armed for wake word” phase or label.

## Recommended architecture

Use a two-stage voice gate:

1. **Wake listener, local only**
   - Add `OpenClickyWakeWordManager` as a small `@MainActor` observable service.
   - It owns its own `AVAudioEngine` input tap while hands-free mode is enabled.
   - It does not stream raw room audio to OpenAI, Deepgram, or any remote service.
   - It emits `wakeDetected` when `Hey Clicky` is heard, then temporarily stops its tap before the main voice capture starts.

2. **Normal OpenClicky voice turn**
   - On wake detection, call the same setup that push-to-talk already uses: cancel old speech, prewarm screenshot capture, clear live computer-use fingerprints, and start the current selected voice pipeline.
   - For the Realtime model path, use the existing `startBidirectionalRealtimeVoiceCapture(source: "wakeWord")` and finish automatically using VAD/silence rather than key release.
   - For non-Realtime transcription providers, reuse `BuddyDictationManager` with a new start source like `.wakeWord` and an automatic silence timeout.

3. **Return to wake listener**
   - After a response completes or a routed app/computer-use command finishes, restart `OpenClickyWakeWordManager` unless the user toggled hands-free mode off.
   - During OpenClicky speech playback, keep wake detection paused to avoid self-triggering from the speaker.

## Wake-word engine choice

The cleanest near-term option is Picovoice Porcupine:

- It supports macOS SDKs and custom wake words.
- It has a Swift low-level API that can be fed frames from an existing audio pipeline.
- It runs wake detection on device, which matches the privacy expectation for always-listening mode.

Implementation note: a custom `Hey Clicky` `.ppn` model would need to be generated in Picovoice Console and bundled with the app or loaded from user config. If we do not want a third-party dependency, the fallback is an Apple Speech / Whisper-style partial transcript gate, but that is heavier, less private for always-on use, and more likely to burn battery or produce false positives.

## Realtime API fit

OpenAI Realtime is useful after wake detection, not as the wake-word detector. Current Realtime docs support server VAD and semantic VAD for turn detection, plus noise reduction. That should be used to end the post-wake utterance naturally, but it should not receive continuous room audio while waiting for `Hey Clicky`.

The current `OpenAIRealtimeSpeechClient.beginBidirectionalVoiceTurn(...)` deliberately sets `turn_detection` to `null`; for wake-word mode we should add a second mode that enables server VAD or semantic VAD and auto-finishes when the user stops speaking.

## Settings/UI shape

Add a Voice setting with three modes:

- **Push to talk**: current behavior.
- **Toggle listening**: activation shortcut toggles wake-word listener on/off; `Hey Clicky` starts a turn.
- **Always listening**: wake-word listener starts on app launch when mic permission is available; shortcut toggles pause/resume.

Suggested status copy:

- Armed: `Say “Hey Clicky”`
- Wake heard: `Listening`
- Thinking: existing `Thinking`
- Speaking: existing `Speaking`

## Code touchpoints

- `GlobalPushToTalkShortcutMonitor.swift`
  - Keep listening for the activation shortcut, but allow mode-specific behavior: hold-to-talk vs toggle wake listener.
- `CompanionManager.swift`
  - Add state: `voiceActivationMode`, `isWakeWordListening`, `isWakeWordPausedForTurn`.
  - Bind wake events to the existing voice turn start path.
  - Add auto-finish handling for wake-word turns.
- `BuddyDictationManager.swift`
  - Add `wakeWord` as a start source if non-Realtime transcription remains supported in hands-free mode.
- `ElevenLabsTTSClient.swift` / `OpenAIRealtimeSpeechClient`
  - Add a Realtime turn mode with `server_vad` or `semantic_vad` instead of `turn_detection: null`.
- `OpenClickySettingsWindowManager.swift` and panel sections
  - Add activation mode controls and privacy copy.
- `OpenClickyNotchCaptureWindowManager.swift`
  - Render armed wake-word state separately from active listening so the user can tell whether OpenClicky is waiting for the wake word or recording the command.

## Safety and privacy rules

- Never stream wake-listener audio off-device.
- Pause wake detection during OpenClicky speech playback.
- Require visible status whenever hands-free listening is armed.
- Log only state transitions (`wake_listener.started`, `wake_word.detected`, `wake_listener.paused_for_turn`), not raw audio.
- Include a hard timeout after wake detection if no command follows.

## First implementation slice

1. Add `OpenClickyWakeWordManager` using a pluggable protocol: `WakeWordDetector.process(pcm16Frame:) -> Bool`.
2. Ship an initial detector adapter around Porcupine, behind a build flag or package dependency.
3. Add the Voice setting and UserDefaults key for activation mode.
4. Wire activation shortcut toggle mode in `handleShortcutTransition(_:)` without removing push-to-talk.
5. On wake detection, call the existing Realtime start path with source `wakeWord`.
6. Add Realtime auto-finish using server/semantic VAD or a local silence timer.
7. Verify with logs and mic-permission failure paths before enabling always-listening on launch.
