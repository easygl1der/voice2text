import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingAPIKeyField = false

    var body: some View {
        TabView {
            // General Tab
            Form {
                Section("Hotkey") {
                    Text("Current: Option + V")
                        .foregroundColor(.secondary)
                }

                Section("Language") {
                    Picker("Default Language", selection: $appState.selectedLanguage) {
                        ForEach(appState.languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // API Tab
            Form {
                Section("Transcription Service") {
                    Picker("Service", selection: $appState.selectedService) {
                        ForEach(TranscriptionService.allCases) { service in
                            Text(service.rawValue).tag(service)
                        }
                    }
                }

                Section("API Key") {
                    if showingAPIKeyField {
                        SecureField("Enter API Key", text: $appState.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        HStack {
                            Text(appState.apiKey.isEmpty ? "Not Set" : "••••••••")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Edit") {
                                showingAPIKeyField = true
                            }
                        }
                    }
                }

                Section {
                    Link("Get Deepgram API Key", destination: URL(string: "https://deepgram.com")!)
                    Link("Get AssemblyAI API Key", destination: URL(string: "https://assemblyai.com")!)
                    Link("Get Mistral API Key", destination: URL(string: "https://mistral.ai")!)
                }
            }
            .tabItem {
                Label("API", systemImage: "key")
            }

            // History Tab
            HistoryListView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(width: 450, height: 350)
    }
}

struct HistoryListView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""

    var filteredTranscripts: [Transcript] {
        if searchText.isEmpty {
            return appState.transcripts
        }
        return appState.transcripts.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            if appState.transcripts.isEmpty {
                Text("No transcripts yet")
                    .foregroundColor(.secondary)
            } else {
                List(filteredTranscripts) { transcript in
                    VStack(alignment: .leading) {
                        Text(transcript.text)
                            .lineLimit(2)
                        HStack {
                            Text(transcript.service)
                                .font(.caption)
                            Text(transcript.language)
                                .font(.caption)
                            Spacer()
                            Text(transcript.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
