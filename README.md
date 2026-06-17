# RemoteControl

Android → macOS remote desktop. Stream your Mac screen to your phone and control the cursor, keyboard, and gestures remotely over LAN or Tailscale.

## Features

- **Real-time screen streaming** — H.264 hardware encoding/decoding (~15 fps)
- **Mouse control** — tap, drag, right-click, middle-click, scroll
- **Mouse hold (drag mode)** — double-tap to toggle
- **Keyboard input** — soft keyboard via IME
- **Authentication** — optional login/password (SHA256)
- **macOS Menu Bar app** — runs in the system tray, no dock icon
- **Permissions management** — grant accessibility & screen recording from the menu
- **Bonjour auto-discovery** (on Android)
- **Works over LAN or Tailscale**

## Quick Start

Prebuilt artifacts are in [`dist/`](./dist/):

| Platform | File | Description |
|----------|------|-------------|
| macOS    | `RemoteControlAgent.dmg` | GUI menu bar app — drag to Applications |
| Android  | `RemoteControl.apk` | App — sideload on device |

## Installation

### macOS — Menu Bar App (GUI)

**Option A: DMG (recommended)**

```bash
open dist/RemoteControlAgent.dmg
# Drag RemoteControlAgent.app to Applications
# Then open from Applications or Spotlight
```

**Option B: Build from source**

```bash
cd macos-agent
./build-app.sh         # creates RemoteControlAgent.app
open RemoteControlAgent.app
```

### macOS — CLI (alternative)

```bash
cd macos-agent
swift build -c release
./.build/release/Agent
```

The agent listens on port `9090` and prints IP addresses.

### Android

**Option A: APK (recommended)**

```bash
adb install -r dist/RemoteControl.apk
```

**Option B: Build from source**

```bash
cd android-app
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Or open `android-app/` in Android Studio and run on device.

## Building Everything

```bash
bash scripts/build-all.sh
# Produces:
#   dist/RemoteControlAgent.dmg
#   dist/RemoteControl.apk
```

### Prerequisites

- **macOS**: Xcode 15+ Command Line Tools
- **Android**: Android Studio Hedgehog+, JDK 17+
- A physical Android device (tested on Android 13+)

## Authentication (optional)

Set a login/password to restrict access:

**Via the menu bar app:** Setup Auth… → enter credentials

**Via CLI:**
```bash
cd macos-agent
swift run Agent --setup-auth     # interactive prompt
swift run Agent --clear-auth     # remove credentials
```

Credentials are stored as SHA256 hash in `~/.remotecontrol/auth.json`.
If no auth file exists, the server allows connections without a password.

## Permissions

The macOS agent needs two permissions. They are shown in the menu bar:

```
● Input: blocked   [Grant]   ← accessibility permission
● Screen: blocked  [Grant]   ← screen recording permission
```

1. Open the menu bar app
2. Click **Grant** next to any blocked permission
3. Allow in **System Settings → Privacy & Security**
4. **Reopen the app** after granting (required by macOS for screen recording)

## Usage

1. Start the macOS agent (open the app or run CLI)
2. Set up authentication if desired
3. Open the Android app
4. Enter the agent's IP address and port (`9090`)
5. Enter login/password if auth is enabled
6. Tap **Connect**
7. The Mac screen appears on your phone:
   - **Tap** → click
   - **Drag** → move with button held
   - **Double-tap** → toggle drag mode
   - Menu → **Keyboard** → soft keyboard

## Architecture

```
┌──────────────┐    TCP (binary protocol)    ┌─────────────┐
│  Android App │◄──────────────────────────►│  macOS Agent │
│  (Kotlin)    │    H.264 video stream       │  (Swift)     │
└──────────────┘    touch/gesture events     └─────────────┘
```

## Protocol

Binary protocol over TCP:

```
[4 bytes: payload length (BE)] [1 byte: message type] [payload]
```

Message types: `MOUSE_MOVE`, `MOUSE_DOWN`, `MOUSE_UP`, `KEY_DOWN`, `KEY_UP`, `CHAR_INPUT`, `VIDEO_FRAME`, `HANDSHAKE`, `HANDSHAKE_REPLY`, `KEEP_ALIVE`, `AUTH`, `AUTH_RESULT`.
