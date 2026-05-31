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

    // MindMap Topics table
    conn.execute(
        r#"
        CREATE TABLE IF NOT EXISTS mindmap_topics (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT,
            pdf_ids TEXT,
            root_note_ids TEXT,
            thumbnail_path TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            last_visit_at INTEGER,
            is_trashed INTEGER DEFAULT 0,
            sync_version INTEGER DEFAULT 0
        )
        "#,
        [],
    ).map_err(|e| format!("Failed to create mindmap_topics table: {}", e))?;

    // MindMap Notes table
    conn.execute(
        r#"
        CREATE TABLE IF NOT EXISTS mindmap_notes (
            id TEXT PRIMARY KEY,
            topic_id TEXT NOT NULL,
            parent_id TEXT,
            title TEXT NOT NULL,
            content_json TEXT,
            child_ids TEXT,
            pdf_id TEXT,
            start_page INTEGER,
            end_page INTEGER,
            start_pos TEXT,
            end_pos TEXT,
            highlight_text TEXT,
            highlight_style TEXT,
            media_ids TEXT,
            position_x REAL,
            position_y REAL,
            z_index INTEGER DEFAULT 0,
            is_collapsed INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            sync_version INTEGER DEFAULT 0,
            FOREIGN KEY (topic_id) REFERENCES mindmap_topics(id)
        )
        "#,
        [],
    ).map_err(|e| format!("Failed to create mindmap_notes table: {}", e))?;

    // Create indexes for mindmap_notes
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_topic ON mindmap_notes(topic_id)",
        [],
    ).map_err(|e| format!("Failed to create idx_notes_topic index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_parent ON mindmap_notes(parent_id)",
        [],
    ).map_err(|e| format!("Failed to create idx_notes_parent index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_notes_pdf ON mindmap_notes(pdf_id)",
        [],
    ).map_err(|e| format!("Failed to create idx_notes_pdf index: {}", e))?;

    // Media Assets table
    conn.execute(
        r#"
        CREATE TABLE IF NOT EXISTS media_assets (
            id TEXT PRIMARY KEY,
            data BLOB NOT NULL,
            thumbnail BLOB,
            media_type TEXT DEFAULT 'image/png',
            created_at INTEGER NOT NULL
        )
        "#,
        [],
    ).map_err(|e| format!("Failed to create media_assets table: {}", e))?;

    // PDF Configs table
    conn.execute(
        r#"
        CREATE TABLE IF NOT EXISTS pdf_configs (
            md5 TEXT PRIMARY KEY,
            title TEXT,
            page_count INTEGER,
            pages_json TEXT,
            current_page INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
        )
        "#,
        [],
    ).map_err(|e| format!("Failed to create pdf_configs table: {}", e))?;

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
