import Foundation
import SQLite3

/// Persistence: one row per minute that contained typing —
/// (epoch minute, keystroke count, seconds of active typing).
/// Key identity is never stored; the schema literally has nowhere to put it.
/// The database lives in ~/Library/Application Support/Keybeat/ and is plain
/// SQLite — open it yourself and check.
final class Store {
    struct Bucket {
        let minute: Int64          // unix time / 60
        let count: Int
        let activeSeconds: Double

        var date: Date { Date(timeIntervalSince1970: Double(minute) * 60) }
    }

    private var db: OpaquePointer?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Keybeat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("keybeat.sqlite").path
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            db = nil
            return
        }
        exec("""
        CREATE TABLE IF NOT EXISTS buckets (
            minute INTEGER PRIMARY KEY,
            count INTEGER NOT NULL,
            active_seconds REAL NOT NULL
        )
        """)
    }

    deinit {
        sqlite3_close(db)
    }

    /// Additive upsert so a relaunch within the same minute never loses counts.
    func add(minute: Int64, count: Int, activeSeconds: Double) {
        let sql = """
        INSERT INTO buckets (minute, count, active_seconds) VALUES (?, ?, ?)
        ON CONFLICT(minute) DO UPDATE SET
            count = count + excluded.count,
            active_seconds = active_seconds + excluded.active_seconds
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, minute)
        sqlite3_bind_int64(stmt, 2, Int64(count))
        sqlite3_bind_double(stmt, 3, activeSeconds)
        sqlite3_step(stmt)
    }

    func buckets(from: Date, to: Date) -> [Bucket] {
        let sql = "SELECT minute, count, active_seconds FROM buckets WHERE minute >= ? AND minute < ? ORDER BY minute"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(from.timeIntervalSince1970 / 60))
        sqlite3_bind_int64(stmt, 2, Int64(to.timeIntervalSince1970 / 60))
        return rows(stmt)
    }

    func allBuckets() -> [Bucket] {
        let sql = "SELECT minute, count, active_seconds FROM buckets ORDER BY minute"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        return rows(stmt)
    }

    private func rows(_ stmt: OpaquePointer?) -> [Bucket] {
        var result: [Bucket] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Bucket(
                minute: sqlite3_column_int64(stmt, 0),
                count: Int(sqlite3_column_int64(stmt, 1)),
                activeSeconds: sqlite3_column_double(stmt, 2)
            ))
        }
        return result
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
