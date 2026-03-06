import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    let onRecord: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.status.rawValue)
                    .font(.system(size: 13))
            }

            Divider()

            // API Selection
            Picker("API", selection: $appState.selectedService) {
                ForEach(TranscriptionService.allCases) { service in
                    Text(service.rawValue).tag(service)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            // Language Selection
            Picker("Language", selection: $appState.selectedLanguage) {
                ForEach(appState.languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Divider()

            // History
            Button(action: {}) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Quit
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 220)
    }

    var statusColor: Color {
        switch appState.status {
        case .ready: return .green
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .gray
        }
    }
}
