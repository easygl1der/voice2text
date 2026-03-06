# Voice2Text

A macOS menu bar app for voice-to-text transcription with global hotkey support.

## Features

- **Global Hotkey**: Press `Option + V` to start/stop recording
- **Multiple API Support**: Deepgram, AssemblyAI, Mistral
- **Auto-Paste**: Transcribed text automatically pastes to cursor position
- **History**: All transcriptions saved locally with SQLite
- **Offline Ready**: Local Whisper support (coming soon)

## Requirements

- macOS 13.0+
- Xcode 15+
- API key from one of the supported services

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/easygl1der/voice2text.git
cd voice2text

# Open in Xcode
open Voice2Text.xcodeproj
```

### Building

1. Select your development team in Xcode
2. Build and run (Cmd + R)

## Setup

### 1. Get API Key

Choose one of the supported services:

- **Deepgram**: [deepgram.com](https://deepgram.com)
- **AssemblyAI**: [assemblyai.com](https://assemblyai.com)
- **Mistral**: [mistral.ai](https://mistral.ai)

### 2. Configure API Key

1. Click the microphone icon in the menu bar
2. Click **Settings**
3. Go to **API** tab
4. Select your preferred service
5. Enter your API key and click Edit to save

### 3. Grant Permissions

On first launch, grant:
- **Microphone access** - required for recording

## Usage

### Recording

1. Press and hold `Option + V` to start recording
2. Speak your text
3. Release `Option + V` to stop

The app will:
1. Send audio to the selected API
2. Receive transcription
3. Automatically paste to your cursor position

### Menu Bar Options

- **Status**: Shows current state (Ready/Recording/Transcribing)
- **API**: Select transcription service
- **Language**: Set language (Chinese/English/Japanese/etc.)
- **Settings**: Open settings window
- **History**: View past transcriptions

### Settings

Access via menu bar → Settings

- **General**: Default language selection
- **API**: API key management
- **History**: Browse and search past transcriptions

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Option + V (hold) | Start/Stop recording |

## Troubleshooting

### "Microphone access denied"

1. Open **System Settings** → **Privacy & Security** → **Microphone**
2. Enable access for Voice2Text

### "API key not configured"

1. Open Settings → API tab
2. Enter your API key

### Global hotkey not working

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Enable accessibility for Voice2Text

## Architecture

```
Voice2Text/
├── App.swift              # Main app entry & AppDelegate
├── Models/
│   └── AppState.swift     # App state & data models
├── Views/
│   ├── MenuBarView.swift # Menu bar UI
│   └── SettingsView.swift # Settings window
└── Services/
    ├── AudioRecorder.swift        # Audio recording
    ├── TranscriptionService.swift # Service manager
    ├── DeepgramClient.swift      # Deepgram API
    ├── AssemblyAIClient.swift    # AssemblyAI API
    ├── MistralClient.swift       # Mistral API
    ├── HotKeyManager.swift       # Global hotkey
    └── HistoryStorage.swift       # SQLite storage
```

## License

MIT
