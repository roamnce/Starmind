// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// comment
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
    pub layout_direction: String,
    pub layout_style: String,
}

/// comment
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

/// comment
/// comment
pub fn create_topic(title: String, author: Option<String>) -> Result<String, String> {
    let id = format!("0-{}", Uuid::new_v4());
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_topics (id, title, author, created_at, updated_at, layout_direction, layout_style) VALUES (?, ?, ?, ?, ?, 'both', 'tree');",
            rusqlite::params![id, title, author, now, now],
        )?;
        Ok(id)
    })
}

/// comment
pub fn get_topic_by_id(id: String) -> Result<Option<Topic>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                    created_at, updated_at, last_visit_at, is_trashed, sync_version,
                    layout_direction, layout_style
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
                layout_direction: row.get::<_, Option<String>>(11)?.unwrap_or_else(|| "both".to_string()),
                layout_style: row.get::<_, Option<String>>(12)?.unwrap_or_else(|| "tree".to_string()),
            }))
        } else {
            Ok(None)
        }
    })
}

/// comment
pub fn update_topic(topic: Topic) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_topics (
                id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                created_at, updated_at, last_visit_at, is_trashed, sync_version,
                layout_direction, layout_style
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                author = excluded.author,
                pdf_ids = excluded.pdf_ids,
                root_note_ids = excluded.root_note_ids,
                thumbnail_path = excluded.thumbnail_path,
                updated_at = ?,
                last_visit_at = excluded.last_visit_at,
                is_trashed = excluded.is_trashed,
                sync_version = mindmap_topics.sync_version + 1,
                layout_direction = excluded.layout_direction,
                layout_style = excluded.layout_style;",
            rusqlite::params![
                topic.id,
                topic.title,
                topic.author,
                topic.pdf_ids,
                topic.root_note_ids,
                topic.thumbnail_path,
                topic.created_at,
                now,
                topic.last_visit_at,
                topic.is_trashed as i32,
                topic.sync_version,
                topic.layout_direction,
                topic.layout_style,
                now
            ],
        )?;
        Ok(())
    })
}

/// comment
pub fn trash_topic(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "UPDATE mindmap_topics SET is_trashed = 1 WHERE id = ?;",
            rusqlite::params![id],
        )?;
        Ok(())
    })
}

/// comment
pub fn get_all_topics() -> Result<Vec<Topic>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                    created_at, updated_at, last_visit_at, is_trashed, sync_version,
                    layout_direction, layout_style
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
                    layout_direction: row.get::<_, Option<String>>(11)?.unwrap_or_else(|| "both".to_string()),
                    layout_style: row.get::<_, Option<String>>(12)?.unwrap_or_else(|| "tree".to_string()),
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(topics)
    })
}

// ==================== Note CRUD ====================

/// comment
/// comment
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

/// comment
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

/// comment
/// comment
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

/// comment
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

/// comment
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

/// comment
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

/// comment
pub fn update_note(note: Note) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_notes (
                id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                media_ids, position_x, position_y, z_index, is_collapsed,
                created_at, updated_at, sync_version
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
                topic_id = excluded.topic_id,
                parent_id = excluded.parent_id,
                title = excluded.title,
                content_json = excluded.content_json,
                child_ids = excluded.child_ids,
                pdf_id = excluded.pdf_id,
                start_page = excluded.start_page,
                end_page = excluded.end_page,
                start_pos = excluded.start_pos,
                end_pos = excluded.end_pos,
                highlight_text = excluded.highlight_text,
                highlight_style = excluded.highlight_style,
                media_ids = excluded.media_ids,
                position_x = excluded.position_x,
                position_y = excluded.position_y,
                z_index = excluded.z_index,
                is_collapsed = excluded.is_collapsed,
                updated_at = ?,
                sync_version = mindmap_notes.sync_version + 1;",
            rusqlite::params![
                note.id,
                note.topic_id,
                note.parent_id,
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
                note.created_at,
                now,
                note.sync_version,
                now
            ],
        )?;
        Ok(())
    })
}

/// comment
pub fn delete_note(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mindmap_notes WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// comment
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

// ==================== Relation CRUD ====================

/// comment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MindMapRelation {
    pub id: String,
    pub topic_id: String,
    pub source_note_id: String,
    pub target_note_id: String,
    pub text: String,
    pub control_points_json: Option<String>,
    pub style: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// comment
pub fn create_relation(
    topic_id: String,
    source_note_id: String,
    target_note_id: String,
    text: String,
) -> Result<String, String> {
    with_db(|conn| {
        // 去重检查与插入在同一把锁内完成，避免双重加锁
        let existing: Option<String> = conn
            .query_row(
                "SELECT id FROM mindmap_relations WHERE topic_id = ? AND source_note_id = ? AND target_note_id = ?;",
                rusqlite::params![topic_id, source_note_id, target_note_id],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        if let Some(id) = existing {
            return Ok(id);
        }

        let id = format!("rel-{}", Uuid::new_v4());
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        conn.execute(
            "INSERT INTO mindmap_relations (id, topic_id, source_note_id, target_note_id, text, style, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, 'solid', ?, ?);",
            rusqlite::params![id, topic_id, source_note_id, target_note_id, text, now, now],
        )?;
        Ok(id)
    })
}

/// comment
pub fn get_relation(id: String) -> Result<Option<MindMapRelation>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, source_note_id, target_note_id, text, control_points_json, style, created_at, updated_at
             FROM mindmap_relations WHERE id = ?;"
        )?;

        let mut rows = stmt.query([&id])?;

        if let Some(row) = rows.next()? {
            Ok(Some(MindMapRelation {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                source_note_id: row.get(2)?,
                target_note_id: row.get(3)?,
                text: row.get(4)?,
                control_points_json: row.get(5)?,
                style: row.get(6)?,
                created_at: row.get(7)?,
                updated_at: row.get(8)?,
            }))
        } else {
            Ok(None)
        }
    })
}

/// comment
pub fn update_relation(relation: MindMapRelation) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mindmap_relations (id, topic_id, source_note_id, target_note_id, text, control_points_json, style, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
                text = excluded.text,
                control_points_json = excluded.control_points_json,
                style = excluded.style,
                updated_at = ?;",
            rusqlite::params![
                relation.id,
                relation.topic_id,
                relation.source_note_id,
                relation.target_note_id,
                relation.text,
                relation.control_points_json,
                relation.style,
                relation.created_at,
                now,
                now
            ],
        )?;
        Ok(())
    })
}

/// comment
pub fn delete_relation(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mindmap_relations WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// comment
pub fn list_relations(topic_id: String) -> Result<Vec<MindMapRelation>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, source_note_id, target_note_id, text, control_points_json, style, created_at, updated_at
             FROM mindmap_relations WHERE topic_id = ?;"
        )?;

        let relations = stmt
            .query_map(rusqlite::params![topic_id], |row| {
                Ok(MindMapRelation {
                    id: row.get(0)?,
                    topic_id: row.get(1)?,
                    source_note_id: row.get(2)?,
                    target_note_id: row.get(3)?,
                    text: row.get(4)?,
                    control_points_json: row.get(5)?,
                    style: row.get(6)?,
                    created_at: row.get(7)?,
                    updated_at: row.get(8)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(relations)
    })
}

/// comment
pub fn find_relation_by_endpoints(
    topic_id: String,
    source_note_id: String,
    target_note_id: String,
) -> Result<Option<MindMapRelation>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, source_note_id, target_note_id, text, control_points_json, style, created_at, updated_at
             FROM mindmap_relations WHERE topic_id = ? AND source_note_id = ? AND target_note_id = ?;"
        )?;

        let mut rows = stmt.query(rusqlite::params![topic_id, source_note_id, target_note_id])?;

        if let Some(row) = rows.next()? {
            Ok(Some(MindMapRelation {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                source_note_id: row.get(2)?,
                target_note_id: row.get(3)?,
                text: row.get(4)?,
                control_points_json: row.get(5)?,
                style: row.get(6)?,
                created_at: row.get(7)?,
                updated_at: row.get(8)?,
            }))
        } else {
            Ok(None)
        }
    })
}

/// comment
pub fn delete_relations_for_note(note_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "DELETE FROM mindmap_relations WHERE source_note_id = ? OR target_note_id = ?;",
            rusqlite::params![note_id, note_id],
        )?;
        Ok(())
    })
}

// ==================== Summary CRUD ====================

/// MindMap Summary entity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MindMapSummary {
    pub id: String,
    pub topic_id: String,
    pub parent_id: String,
    pub start_index: i32,
    pub end_index: i32,
    pub text: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// Create a new summary
pub fn create_summary(
    topic_id: String,
    parent_id: String,
    start_index: i32,
    end_index: i32,
    text: String,
) -> Result<String, String> {
    let id = format!("sum-{}", Uuid::new_v4());
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        let existing: Option<String> = conn
            .query_row(
                "SELECT id FROM mindmap_summaries WHERE topic_id = ? AND parent_id = ? AND start_index = ? AND end_index = ?;",
                rusqlite::params![topic_id, parent_id, start_index, end_index],
                |row| row.get(0),
            )
            .ok()
            .flatten();

        if let Some(existing_id) = existing {
            return Ok(existing_id);
        }

        conn.execute(
            "INSERT INTO mindmap_summaries (id, topic_id, parent_id, start_index, end_index, text, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?);",
            rusqlite::params![id, topic_id, parent_id, start_index, end_index, text, now, now],
        )?;
        Ok(id)
    })
}

/// Get summary by ID
pub fn get_summary(id: String) -> Result<Option<MindMapSummary>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, parent_id, start_index, end_index, text, created_at, updated_at
             FROM mindmap_summaries WHERE id = ?;"
        )?;

        let mut rows = stmt.query(rusqlite::params![id])?;

        if let Some(row) = rows.next()? {
            Ok(Some(MindMapSummary {
                id: row.get(0)?,
                topic_id: row.get(1)?,
                parent_id: row.get(2)?,
                start_index: row.get(3)?,
                end_index: row.get(4)?,
                text: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
            }))
        } else {
            Ok(None)
        }
    })
}

/// Update summary
pub fn update_summary(summary: MindMapSummary) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "UPDATE mindmap_summaries SET parent_id = ?, start_index = ?, end_index = ?, text = ?, updated_at = ? WHERE id = ?;",
            rusqlite::params![
                summary.parent_id,
                summary.start_index,
                summary.end_index,
                summary.text,
                now,
                summary.id
            ],
        )?;
        Ok(())
    })
}

/// Delete summary
pub fn delete_summary(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mindmap_summaries WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// List all summaries for a topic
pub fn list_summaries(topic_id: String) -> Result<Vec<MindMapSummary>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, parent_id, start_index, end_index, text, created_at, updated_at
             FROM mindmap_summaries WHERE topic_id = ? ORDER BY parent_id, start_index;"
        )?;

        let summaries = stmt
            .query_map(rusqlite::params![topic_id], |row| {
                Ok(MindMapSummary {
                    id: row.get(0)?,
                    topic_id: row.get(1)?,
                    parent_id: row.get(2)?,
                    start_index: row.get(3)?,
                    end_index: row.get(4)?,
                    text: row.get(5)?,
                    created_at: row.get(6)?,
                    updated_at: row.get(7)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(summaries)
    })
}

/// Delete summaries for a parent note
pub fn delete_summaries_for_note(note_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "DELETE FROM mindmap_summaries WHERE parent_id = ?;",
            rusqlite::params![note_id],
        )?;
        Ok(())
    })
}

// ==================== Note-Tag Binding ====================

/// Bind a tag to a note
pub fn bind_tag_to_note(note_id: String, tag_id: String) -> Result<(), String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT OR IGNORE INTO mindmap_note_tags (note_id, tag_id, created_at) VALUES (?, ?, ?);",
            rusqlite::params![note_id, tag_id, now],
        )?;
        Ok(())
    })
}

/// Unbind a tag from a note
pub fn unbind_tag_from_note(note_id: String, tag_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "DELETE FROM mindmap_note_tags WHERE note_id = ? AND tag_id = ?;",
            rusqlite::params![note_id, tag_id],
        )?;
        Ok(())
    })
}

/// List tag IDs for a note
pub fn list_tag_ids_for_note(note_id: String) -> Result<Vec<String>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT tag_id FROM mindmap_note_tags WHERE note_id = ?;"
        )?;

        let tag_ids = stmt
            .query_map(rusqlite::params![note_id], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(tag_ids)
    })
}

/// 批量查询 Topic 下所有节点的标签绑定。
///
/// 返回 `HashMap<note_id, Vec<tag_id>>`，仅包含有绑定的节点。
pub fn list_tag_ids_for_topic(topic_id: String) -> Result<std::collections::HashMap<String, Vec<String>>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT nt.note_id, nt.tag_id \
             FROM mindmap_note_tags nt \
             INNER JOIN mindmap_notes n ON n.id = nt.note_id \
             WHERE n.topic_id = ?;"
        )?;

        let mut map: std::collections::HashMap<String, Vec<String>> = std::collections::HashMap::new();
        let mut rows = stmt.query(rusqlite::params![topic_id])?;
        while let Some(row) = rows.next()? {
            let note_id: String = row.get(0)?;
            let tag_id: String = row.get(1)?;
            map.entry(note_id).or_default().push(tag_id);
        }
        Ok(map)
    })
}

/// Delete all tag bindings for a note
pub fn delete_note_tag_bindings_for_note(note_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "DELETE FROM mindmap_note_tags WHERE note_id = ?;",
            rusqlite::params![note_id],
        )?;
        Ok(())
    })
}
