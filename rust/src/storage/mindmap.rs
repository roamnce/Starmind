// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Topic (笔记本) 实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Topic {
    pub id: String,
    pub title: String,
    pub author: Option<String>,
    pub pdf_ids: Option<String>, // 管道分隔
    pub root_note_ids: Option<String>, // 管道分隔
    pub thumbnail_path: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub last_visit_at: Option<i64>,
    pub is_trashed: bool,
    pub sync_version: i64,
}

/// Note (导图节点) 实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: String,
    pub topic_id: String,
    pub parent_id: Option<String>,
    pub title: String,
    pub content_json: Option<String>,
    pub child_ids: Option<String>, // 管道分隔
    pub pdf_id: Option<String>,
    pub start_page: Option<i32>,
    pub end_page: Option<i32>,
    pub start_pos: Option<String>,
    pub end_pos: Option<String>,
    pub highlight_text: Option<String>,
    pub highlight_style: Option<String>,
    pub media_ids: Option<String>, // 管道分隔
    pub position_x: Option<f64>,
    pub position_y: Option<f64>,
    pub z_index: i32,
    pub is_collapsed: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub sync_version: i64,
}

// ==================== Topic CRUD ====================

/// Creates a new Topic (笔记本) and returns its ID.
/// ID format: "0-{UUID}"
pub fn create_topic(title: String, author: Option<String>) -> Result<String, String> {
    let id = format!("0-{}", Uuid::new_v4());
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_topics (id, title, author, created_at, updated_at) VALUES (?, ?, ?, ?, ?);",
            rusqlite::params![id, title, author, now, now],
        )?;
        Ok(id)
    })
}

/// Gets a Topic by its ID.
pub fn get_topic_by_id(id: String) -> Result<Option<Topic>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                    created_at, updated_at, last_visit_at, is_trashed, sync_version
             FROM mindmap_topics WHERE id = ?;"
        )?;

        let mut rows = stmt.query([&id])?;

        if let Some(row) = rows.next()? {
            Ok(Some(Topic {
                id: row.get(0)?,
                title: row.get(1)?,
                author: row.get(2)?,
                pdf_ids: row.get(3)?,
                root_note_ids: row.get(4)?,
                thumbnail_path: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
                last_visit_at: row.get(8)?,
                is_trashed: row.get::<_, i32>(9)? == 1,
                sync_version: row.get(10)?,
            }))
        } else {
            Ok(None)
        }
    })
}

/// Updates a Topic.
pub fn update_topic(topic: Topic) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "UPDATE mindmap_topics SET title = ?, author = ?, pdf_ids = ?,
             root_note_ids = ?, updated_at = ?, sync_version = sync_version + 1
             WHERE id = ?;",
            rusqlite::params![
                topic.title,
                topic.author,
                topic.pdf_ids,
                topic.root_note_ids,
                now,
                topic.id
            ],
        )?;
        Ok(())
    })
}

/// Soft deletes a Topic (marks as trashed).
pub fn trash_topic(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "UPDATE mindmap_topics SET is_trashed = 1 WHERE id = ?;",
            rusqlite::params![id],
        )?;
        Ok(())
    })
}

/// Gets all non-trashed Topics.
pub fn get_all_topics() -> Result<Vec<Topic>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                    created_at, updated_at, last_visit_at, is_trashed, sync_version
             FROM mindmap_topics WHERE is_trashed = 0 ORDER BY updated_at DESC;"
        )?;

        let topics = stmt
            .query_map([], |row| {
                Ok(Topic {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    author: row.get(2)?,
                    pdf_ids: row.get(3)?,
                    root_note_ids: row.get(4)?,
                    thumbnail_path: row.get(5)?,
                    created_at: row.get(6)?,
                    updated_at: row.get(7)?,
                    last_visit_at: row.get(8)?,
                    is_trashed: row.get::<_, i32>(9)? == 1,
                    sync_version: row.get(10)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(topics)
    })
}

// ==================== Note CRUD ====================

/// Creates a new Note (导图节点) and returns its ID.
/// ID format: "1-{UUID}"
pub fn create_note(
    topic_id: String,
    title: String,
    parent_id: Option<String>,
) -> Result<String, String> {
    let id = format!("1-{}", Uuid::new_v4());
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_notes (id, topic_id, parent_id, title, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?);",
            rusqlite::params![id, topic_id, parent_id, title, now, now],
        )?;
        Ok(id)
    })
}

/// Gets a Note by its ID.
pub fn get_note_by_id(id: String) -> Result<Option<Note>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                    start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                    media_ids, position_x, position_y, z_index, is_collapsed,
                    created_at, updated_at, sync_version
             FROM mindmap_notes WHERE id = ?;"
        )?;

        let mut rows = stmt.query([&id])?;

        if let Some(row) = rows.next()? {
            Ok(Some(Note {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                parent_id: row.get(2)?,
                title: row.get(3)?,
                content_json: row.get(4)?,
                child_ids: row.get(5)?,
                pdf_id: row.get(6)?,
                start_page: row.get(7)?,
                end_page: row.get(8)?,
                start_pos: row.get(9)?,
                end_pos: row.get(10)?,
                highlight_text: row.get(11)?,
                highlight_style: row.get(12)?,
                media_ids: row.get(13)?,
                position_x: row.get(14)?,
                position_y: row.get(15)?,
                z_index: row.get(16)?,
                is_collapsed: row.get::<_, i32>(17)? == 1,
                created_at: row.get(18)?,
                updated_at: row.get(19)?,
                sync_version: row.get(20)?,
            }))
        } else {
            Ok(None)
        }
    })
}

/// Adds a child to a Note (appends to pipe-separated child_ids).
/// Also updates the child's parent_id for reverse lookup.
pub fn add_child_to_note(parent_id: String, child_id: String) -> Result<(), String> {
    with_db(|conn| {
        // Get current child_ids
        let current: Option<String> = conn
            .query_row(
                "SELECT child_ids FROM mindmap_notes WHERE id = ?;",
                rusqlite::params![parent_id],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        // Append new child
        let new_child_ids = match current {
            Some(mut s) if !s.is_empty() => {
                s.push('|');
                s.push_str(&child_id);
                s
            }
            _ => child_id.clone(),
        };

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        // Update parent's child_ids
        conn.execute(
            "UPDATE mindmap_notes SET child_ids = ?, updated_at = ? WHERE id = ?;",
            rusqlite::params![new_child_ids, now, parent_id],
        )?;

        // Update child's parent_id (reverse index optimization)
        conn.execute(
            "UPDATE mindmap_notes SET parent_id = ?, updated_at = ? WHERE id = ?;",
            rusqlite::params![parent_id, now, child_id],
        )?;

        Ok(())
    })
}

/// Gets all children of a Note by parsing the pipe-separated child_ids.
pub fn get_note_children(parent_id: String) -> Result<Vec<Note>, String> {
    with_db(|conn| {
        // Get child_ids string
        let child_ids_str: Option<String> = conn
            .query_row(
                "SELECT child_ids FROM mindmap_notes WHERE id = ?;",
                rusqlite::params![parent_id],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        let child_ids_str = match child_ids_str {
            Some(s) if !s.is_empty() => s,
            _ => return Ok(vec![]),
        };

        // Split ID list
        let ids: Vec<&str> = child_ids_str.split('|').filter(|s| !s.is_empty()).collect();
        if ids.is_empty() {
            return Ok(vec![]);
        }

        // Batch query children
        let placeholders = ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                    start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                    media_ids, position_x, position_y, z_index, is_collapsed,
                    created_at, updated_at, sync_version
             FROM mindmap_notes WHERE id IN ({});",
            placeholders
        );

        let mut stmt = conn.prepare(&sql)?;
        let params: Vec<&dyn rusqlite::ToSql> = ids.iter().map(|s| s as &dyn rusqlite::ToSql).collect();
        let mut rows = stmt.query(params.as_slice())?;

        let mut notes = Vec::new();
        while let Some(row) = rows.next()? {
            notes.push(Note {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                parent_id: row.get(2)?,
                title: row.get(3)?,
                content_json: row.get(4)?,
                child_ids: row.get(5)?,
                pdf_id: row.get(6)?,
                start_page: row.get(7)?,
                end_page: row.get(8)?,
                start_pos: row.get(9)?,
                end_pos: row.get(10)?,
                highlight_text: row.get(11)?,
                highlight_style: row.get(12)?,
                media_ids: row.get(13)?,
                position_x: row.get(14)?,
                position_y: row.get(15)?,
                z_index: row.get(16)?,
                is_collapsed: row.get::<_, i32>(17)? == 1,
                created_at: row.get(18)?,
                updated_at: row.get(19)?,
                sync_version: row.get(20)?,
            });
        }

        notes.sort_by_key(|note| {
            ids.iter()
                .position(|id| *id == note.id)
                .unwrap_or(usize::MAX)
        });

        Ok(notes)
    })
}

/// Gets all Notes associated with a specific PDF.
pub fn get_notes_by_pdf(pdf_id: String) -> Result<Vec<Note>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                    start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                    media_ids, position_x, position_y, z_index, is_collapsed,
                    created_at, updated_at, sync_version
             FROM mindmap_notes WHERE pdf_id = ? ORDER BY start_page;"
        )?;

        let mut rows = stmt.query(rusqlite::params![pdf_id])?;

        let mut notes = Vec::new();
        while let Some(row) = rows.next()? {
            notes.push(Note {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                parent_id: row.get(2)?,
                title: row.get(3)?,
                content_json: row.get(4)?,
                child_ids: row.get(5)?,
                pdf_id: row.get(6)?,
                start_page: row.get(7)?,
                end_page: row.get(8)?,
                start_pos: row.get(9)?,
                end_pos: row.get(10)?,
                highlight_text: row.get(11)?,
                highlight_style: row.get(12)?,
                media_ids: row.get(13)?,
                position_x: row.get(14)?,
                position_y: row.get(15)?,
                z_index: row.get(16)?,
                is_collapsed: row.get::<_, i32>(17)? == 1,
                created_at: row.get(18)?,
                updated_at: row.get(19)?,
                sync_version: row.get(20)?,
            });
        }

        Ok(notes)
    })
}

/// Gets all Notes belonging to a Topic.
pub fn get_notes_by_topic(topic_id: String) -> Result<Vec<Note>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                    start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                    media_ids, position_x, position_y, z_index, is_collapsed,
                    created_at, updated_at, sync_version
             FROM mindmap_notes WHERE topic_id = ? ORDER BY created_at;"
        )?;

        let notes = stmt
            .query_map(rusqlite::params![topic_id], |row| {
                Ok(Note {
                    id: row.get(0)?,
                    topic_id: row.get(1)?,
                    parent_id: row.get(2)?,
                    title: row.get(3)?,
                    content_json: row.get(4)?,
                    child_ids: row.get(5)?,
                    pdf_id: row.get(6)?,
                    start_page: row.get(7)?,
                    end_page: row.get(8)?,
                    start_pos: row.get(9)?,
                    end_pos: row.get(10)?,
                    highlight_text: row.get(11)?,
                    highlight_style: row.get(12)?,
                    media_ids: row.get(13)?,
                    position_x: row.get(14)?,
                    position_y: row.get(15)?,
                    z_index: row.get(16)?,
                    is_collapsed: row.get::<_, i32>(17)? == 1,
                    created_at: row.get(18)?,
                    updated_at: row.get(19)?,
                    sync_version: row.get(20)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(notes)
    })
}

/// Updates a Note.
pub fn update_note(note: Note) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "UPDATE mindmap_notes SET
                title = ?, content_json = ?, child_ids = ?, pdf_id = ?,
                start_page = ?, end_page = ?, start_pos = ?, end_pos = ?,
                highlight_text = ?, highlight_style = ?, media_ids = ?,
                position_x = ?, position_y = ?, z_index = ?, is_collapsed = ?,
                updated_at = ?, sync_version = sync_version + 1
             WHERE id = ?;",
            rusqlite::params![
                note.title,
                note.content_json,
                note.child_ids,
                note.pdf_id,
                note.start_page,
                note.end_page,
                note.start_pos,
                note.end_pos,
                note.highlight_text,
                note.highlight_style,
                note.media_ids,
                note.position_x,
                note.position_y,
                note.z_index,
                note.is_collapsed as i32,
                now,
                note.id
            ],
        )?;
        Ok(())
    })
}

/// Deletes a Note (hard delete).
pub fn delete_note(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mindmap_notes WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// Removes a child from a Note's child_ids (pipe-separated).
pub fn remove_child_from_note(parent_id: String, child_id: String) -> Result<(), String> {
    with_db(|conn| {
        // Get current child_ids
        let current: Option<String> = conn
            .query_row(
                "SELECT child_ids FROM mindmap_notes WHERE id = ?;",
                rusqlite::params![parent_id],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        let current = match current {
            Some(s) if !s.is_empty() => s,
            _ => return Ok(()), // No children to remove
        };

        // Remove the child_id from pipe-separated list
        let ids: Vec<&str> = current.split('|').filter(|s| *s != child_id).collect();
        let new_child_ids = ids.join("|");

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        // Update parent's child_ids
        conn.execute(
            "UPDATE mindmap_notes SET child_ids = ?, updated_at = ? WHERE id = ?;",
            rusqlite::params![new_child_ids, now, parent_id],
        )?;

        // Clear child's parent_id
        conn.execute(
            "UPDATE mindmap_notes SET parent_id = NULL, updated_at = ? WHERE id = ?;",
            rusqlite::params![now, child_id],
        )?;

        Ok(())
    })
}