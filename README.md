# Voice2Text

A macOS menu bar application for voice-to-text transcription with global hotkey support.

## Features

- **Global Hotkey**: Press Option + V (configurable) to start/stop recording
- **Multiple Transcription Services**: Supports Deepgram, AssemblyAI, and Mistral
- **Auto-Paste**: Automatically inserts transcribed text at cursor position
- **History Storage**: SQLite-based local storage for all transcriptions
- **Menu Bar Interface**: Quick access to settings, history, and status

## Requirements

- macOS 12.0+
- Xcode 15.0+
- API keys for selected transcription service (Deepgram, AssemblyAI, or Mistral)

## Setup

1. Clone the repository
2. Open `Voice2Text/Voice2Text.xcodeproj` in Xcode
3. Add your API key in Settings (via menu bar icon)
4. Grant microphone and accessibility permissions when prompted
5. Build and run (⌘+R)

## Configuration

Access settings via the menu bar icon:
- Select transcription service (Deepgram/AssemblyAI/Mistral)
- Configure API key
- Customize hotkey
- View transcription history

## Architecture

```
Voice2Text/
├── App.swift              # App entry point
├── Views/
│   ├── MenuBarView.swift  # Menu bar UI
│   └── SettingsView.swift # Settings panel
├── Services/
│   ├── AudioRecorder.swift       # Audio recording
│   ├── TranscriptionService.swift # Transcription orchestration
│   ├── DeepgramClient.swift      # Deepgram API
│   ├── AssemblyAIClient.swift    # AssemblyAI API
│   ├── MistralClient.swift       # Mistral API
│   ├── HotKeyManager.swift       # Global hotkey
│   └── HistoryStorage.swift       # SQLite storage
└── Models/
    └── AppState.swift     # App state management
```

## Permissions Required

- **Microphone**: For voice recording
- **Accessibility**: For global hotkey and auto-paste

## License

MIT
