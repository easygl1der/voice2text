import Foundation
import SQLite

class HistoryStorage {
    private var db: Connection?
    private let transcripts = Table("transcripts")

    // Columns
    private let id = SQLite.Expression<String>("id")
    private let text = SQLite.Expression<String>("text")
    private let timestamp = SQLite.Expression<Date>("timestamp")
    private let service = SQLite.Expression<String>("service")
    private let language = SQLite.Expression<String>("language")

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbPath = documentsPath.appendingPathComponent("voice2text.sqlite3").path
            db = try Connection(dbPath)

            try db?.run(transcripts.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(text)
                t.column(timestamp)
                t.column(service)
                t.column(language)
            })
        } catch {
            print("Database setup error: \(error)")
        }
    }

    func save(_ transcript: Transcript) {
        do {
            let insert = transcripts.insert(
                id <- transcript.id.uuidString,
                text <- transcript.text,
                timestamp <- transcript.timestamp,
                service <- transcript.service,
                language <- transcript.language
            )
            try db?.run(insert)
        } catch {
            print("Save error: \(error)")
        }
    }

    func loadAll() -> [Transcript] {
        var results: [Transcript] = []

        do {
            let query = transcripts.order(timestamp.desc)
            if let rows = try db?.prepare(query) {
                for row in rows {
                    let transcript = Transcript(
                        text: row[text],
                        service: row[service],
                        language: row[language]
                    )
                    results.append(transcript)
                }
            }
        } catch {
            print("Load error: \(error)")
        }

        return results
    }

    func delete(id transcriptId: UUID) {
        do {
            let transcript = transcripts.filter(id == transcriptId.uuidString)
            try db?.run(transcript.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }

    func search(query searchText: String) -> [Transcript] {
        var results: [Transcript] = []

        do {
            let searchQuery = transcripts.filter(text.like("%\(searchText)%")).order(timestamp.desc)
            if let rows = try db?.prepare(searchQuery) {
                for row in rows {
                    let transcript = Transcript(
                        text: row[text],
                        service: row[service],
                        language: row[language]
                    )
                    results.append(transcript)
                }
            }
        } catch {
            print("Search error: \(error)")
        }

        return results
    }
}
