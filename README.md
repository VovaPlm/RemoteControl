# RemoteControl

Android → macOS remote desktop. Stream your Mac screen to your phone and control the cursor, keyboard, and gestures remotely over your local network or Tailscale.

## Architecture

```
┌──────────────┐    TCP (binary protocol)    ┌─────────────┐
│  Android App │◄──────────────────────────►│  macOS Agent │
│  (Kotlin)    │    H.264 video stream       │  (Swift)     │
└──────────────┘    touch/gesture events     └─────────────┘
```

- **Android app**: Compose UI, H.264 hardware decoding (MediaCodec), gesture capture
- **macOS agent**: Screen capture via `CGDisplayStream`, H.264 encoding (VideoToolbox), mouse/keyboard injection via `CGEvent`

## Features

- 📱 Real-time screen streaming (H.264, ~15 fps)
- 🖱️ Mouse control (tap, drag, right-click, middle-click)
- ⌨️ Keyboard input via soft keyboard (IME)
- 🔄 Double-tap to toggle mouse hold (drag mode)
- 🌐 Works over LAN or Tailscale
- 📡 Bonjour auto-discovery (client-side)

## Features

- 🔐 **Authentication** — set login/password on the agent via CLI or GUI; Android prompts for credentials
- 🖥️ **macOS Menu Bar app** — runs as a background service with a menu bar icon

## Building

### Prerequisites

- **macOS**: Xcode 15+ (Command Line Tools)
- **Android**: Android Studio Hedgehog+, JDK 17+
- A physical Android device (tested on Android 13+)

### macOS Agent

#### Menu Bar app (GUI)

```bash
cd macos-agent
./build-app.sh        # builds release + creates RemoteControlAgent.app
open RemoteControlAgent.app
```

Or open the script result in Finder and drag to Applications.

#### CLI (alternative)

```bash
cd macos-agent
swift build -c release
./.build/release/Agent
```

The agent listens on port `9090` and prints the IP addresses to connect to.

### Authentication setup

```bash
cd macos-agent
swift run Agent --setup-auth     # interactive: enter login + password
swift run Agent --clear-auth     # remove credentials
```

Or use the menu bar app → **Setup Auth…**.

### Android App

```bash
cd android-app
./gradlew assembleDebug
```

Install on device:
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Or open `android-app/` in Android Studio and run on device.

## Usage

1. Start the macOS agent (app or CLI)
2. Set up authentication if desired: `swift run Agent --setup-auth`
3. Open the Android app, enter the agent's IP, port (default `9090`), login and password
4. Tap **Connect**
5. The Mac screen appears on your phone
6. **Tap** → click, **Drag** → move with button held
7. Menu → **Keyboard** → opens soft keyboard for text input
8. **Double-tap** → toggle drag mode (mouse stays held)

## Protocol

Binary protocol over TCP:

```
[4 bytes: payload length (BE)] [1 byte: message type] [payload]
```

Message types: `MOUSE_MOVE`, `MOUSE_DOWN`, `MOUSE_UP`, `KEY_DOWN`, `KEY_UP`, `CHAR_INPUT`, `VIDEO_FRAME`, `HANDSHAKE`, `KEEP_ALIVE`, etc.

The handshake exchanges screen dimensions so the client maps touch coordinates to the correct video space.
