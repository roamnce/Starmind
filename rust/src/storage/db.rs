// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use once_cell::sync::Lazy;
use rusqlite::Connection;
use std::sync::Mutex;

static DB: Lazy<Mutex<Option<Connection>>> = Lazy::new(|| Mutex::new(None));

/// Initializes the global SQLite connection at the specified `db_path` and
/// executes the schema migration DDL scripts.
pub fn init_db(db_path: &str) -> Result<(), String> {
    let mut db_guard = DB.lock().map_err(|e| format!("Failed to lock DB: {}", e))?;

    if db_guard.is_some() {
        return Ok(()); // Already initialized
    }

    let conn = Connection::open(db_path)
        .map_err(|e| format!("Failed to open SQLite database at {}: {}", db_path, e))?;

    // Enable foreign keys
    conn.execute("PRAGMA foreign_keys = ON;", [])
        .map_err(|e| format!("Failed to enable foreign keys: {}", e))?;

    // Create folders table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(parent_id) REFERENCES folders(id) ON DELETE CASCADE
        );",
        [],
    ).map_err(|e| format!("Failed to create folders table: {}", e))?;

    // Create tags table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            color_hex TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(parent_id) REFERENCES tags(id) ON DELETE CASCADE
        );",
        [],
    ).map_err(|e| format!("Failed to create tags table: {}", e))?;

    // Create documents table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            file_path TEXT NOT NULL,
            folder_id TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE SET NULL
        );",
        [],
    ).map_err(|e| format!("Failed to create documents table: {}", e))?;

    // Create document_tags table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS document_tags (
            document_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            PRIMARY KEY (document_id, tag_id),
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
            FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
        );",
        [],
    ).map_err(|e| format!("Failed to create document_tags table: {}", e))?;

    // Create annotations table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS annotations (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            page_index INTEGER NOT NULL,
            annotation_type TEXT NOT NULL,
            is_standard BOOLEAN NOT NULL,
            color_hex TEXT DEFAULT '#FFFF00',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            start_char_index INTEGER,
            end_char_index INTEGER,
            selected_text TEXT,
            rects_json TEXT,
            strokes_json TEXT,
            note_content TEXT,
            note_rect_json TEXT,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
        );",
        [],
    ).map_err(|e| format!("Failed to create annotations table: {}", e))?;

    // Create annotation indexes
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_annotations_document ON annotations(document_id);",
        [],
    ).map_err(|e| format!("Failed to create annotations document index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_annotations_page ON annotations(document_id, page_index);",
        [],
    ).map_err(|e| format!("Failed to create annotations page index: {}", e))?;

    *db_guard = Some(conn);
    Ok(())
}

/// Helper block executing transactions on the global database.
pub fn with_db<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce(&Connection) -> Result<R, rusqlite::Error>,
{
    let db_guard = DB.lock().map_err(|e| format!("Failed to lock DB: {}", e))?;
    let conn = db_guard.as_ref().ok_or("Database has not been initialized. Call init_storage first.")?;
    f(conn).map_err(|e| format!("SQLite operation failed: {}", e))
}
