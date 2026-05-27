// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Annotation types supported by Starmind.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AnnotationType {
    Highlight,
    Underline,
    Wave,
    Ink,
    Note,
}

impl AnnotationType {
    pub fn as_str(&self) -> &'static str {
        match self {
            AnnotationType::Highlight => "highlight",
            AnnotationType::Underline => "underline",
            AnnotationType::Wave => "wave",
            AnnotationType::Ink => "ink",
            AnnotationType::Note => "note",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "underline" => AnnotationType::Underline,
            "wave" => AnnotationType::Wave,
            "ink" => AnnotationType::Ink,
            "note" => AnnotationType::Note,
            _ => AnnotationType::Highlight,
        }
    }
}

/// Rectangular region on a PDF page.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnnotationRect {
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

/// Ink stroke point.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InkPoint {
    pub x: f32,
    pub y: f32,
}

/// Ink stroke.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InkStroke {
    pub points: Vec<InkPoint>,
    pub color: u32,
    pub stroke_width: f32,
    #[serde(default)]
    pub is_highlighter: bool,
}

/// Annotation record for database storage.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnnotationRecord {
    pub id: String,
    pub document_id: String,
    pub page_index: i32,
    pub annotation_type: String,
    pub is_standard: bool,
    pub color_hex: String,
    pub created_at: i64,
    pub modified_at: i64,

    // Text-based annotation fields
    pub start_char_index: Option<i32>,
    pub end_char_index: Option<i32>,
    pub selected_text: Option<String>,
    pub rects_json: Option<String>,

    // Handwriting annotation fields
    pub strokes_json: Option<String>,

    // Text note fields
    pub note_content: Option<String>,
    pub note_rect_json: Option<String>,
}

/// Creates the annotations table if it doesn't exist.
pub fn init_annotations_table() -> Result<(), String> {
    with_db(|conn| {
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
        )?;

        // Create indexes
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_annotations_document ON annotations(document_id);",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_annotations_page ON annotations(document_id, page_index);",
            [],
        )?;

        Ok(())
    })
}

/// Creates a new annotation and returns its ID.
pub fn create_annotation(annotation: AnnotationRecord) -> Result<String, String> {
    with_db(|conn| {
        conn.execute(
            "INSERT INTO annotations (
                id, document_id, page_index, annotation_type, is_standard, color_hex,
                created_at, modified_at, start_char_index, end_char_index, selected_text,
                rects_json, strokes_json, note_content, note_rect_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            rusqlite::params![
                annotation.id,
                annotation.document_id,
                annotation.page_index,
                annotation.annotation_type,
                annotation.is_standard,
                annotation.color_hex,
                annotation.created_at,
                annotation.modified_at,
                annotation.start_char_index,
                annotation.end_char_index,
                annotation.selected_text,
                annotation.rects_json,
                annotation.strokes_json,
                annotation.note_content,
                annotation.note_rect_json,
            ],
        )?;
        Ok(annotation.id)
    })
}

/// Gets all annotations for a document.
pub fn get_annotations(document_id: String) -> Result<Vec<AnnotationRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, document_id, page_index, annotation_type, is_standard, color_hex,
                    created_at, modified_at, start_char_index, end_char_index, selected_text,
                    rects_json, strokes_json, note_content, note_rect_json
             FROM annotations WHERE document_id = ? ORDER BY page_index, created_at;"
        )?;

        let records = stmt.query_map([&document_id], |row| {
            Ok(AnnotationRecord {
                id: row.get(0)?,
                document_id: row.get(1)?,
                page_index: row.get(2)?,
                annotation_type: row.get(3)?,
                is_standard: row.get(4)?,
                color_hex: row.get(5)?,
                created_at: row.get(6)?,
                modified_at: row.get(7)?,
                start_char_index: row.get(8)?,
                end_char_index: row.get(9)?,
                selected_text: row.get(10)?,
                rects_json: row.get(11)?,
                strokes_json: row.get(12)?,
                note_content: row.get(13)?,
                note_rect_json: row.get(14)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;

        Ok(records)
    })
}

/// Gets annotations for a specific page.
pub fn get_annotations_for_page(
    document_id: String,
    page_index: i32,
) -> Result<Vec<AnnotationRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, document_id, page_index, annotation_type, is_standard, color_hex,
                    created_at, modified_at, start_char_index, end_char_index, selected_text,
                    rects_json, strokes_json, note_content, note_rect_json
             FROM annotations WHERE document_id = ? AND page_index = ? ORDER BY created_at;"
        )?;

        let records = stmt.query_map(rusqlite::params![document_id, page_index], |row| {
            Ok(AnnotationRecord {
                id: row.get(0)?,
                document_id: row.get(1)?,
                page_index: row.get(2)?,
                annotation_type: row.get(3)?,
                is_standard: row.get(4)?,
                color_hex: row.get(5)?,
                created_at: row.get(6)?,
                modified_at: row.get(7)?,
                start_char_index: row.get(8)?,
                end_char_index: row.get(9)?,
                selected_text: row.get(10)?,
                rects_json: row.get(11)?,
                strokes_json: row.get(12)?,
                note_content: row.get(13)?,
                note_rect_json: row.get(14)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;

        Ok(records)
    })
}

/// Updates an annotation.
pub fn update_annotation(id: String, updates: std::collections::HashMap<String, String>) -> Result<(), String> {
    with_db(|conn| {
        let modified_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        let mut set_parts = Vec::new();
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = vec![];

        for (key, value) in updates {
            set_parts.push(format!("{} = ?", key));
            params.push(Box::new(value));
        }
        set_parts.push("modified_at = ?".to_string());
        params.push(Box::new(modified_at));

        params.push(Box::new(id.clone()));

        let sql = format!(
            "UPDATE annotations SET {} WHERE id = ?;",
            set_parts.join(", ")
        );

        let params_refs: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p.as_ref()).collect();
        conn.execute(&sql, params_refs.as_slice())?;

        Ok(())
    })
}

/// Deletes an annotation.
pub fn delete_annotation(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM annotations WHERE id = ?;", [&id])?;
        Ok(())
    })
}

/// Deletes all annotations for a document.
pub fn delete_annotations_for_document(document_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM annotations WHERE document_id = ?;", [&document_id])?;
        Ok(())
    })
}

/// Creates a new annotation with auto-generated ID.
pub fn create_annotation_auto_id(
    document_id: String,
    page_index: i32,
    annotation_type: String,
    is_standard: bool,
    color_hex: String,
    start_char_index: Option<i32>,
    end_char_index: Option<i32>,
    selected_text: Option<String>,
    rects_json: Option<String>,
    strokes_json: Option<String>,
    note_content: Option<String>,
    note_rect_json: Option<String>,
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    let annotation = AnnotationRecord {
        id,
        document_id,
        page_index,
        annotation_type,
        is_standard,
        color_hex,
        created_at: now,
        modified_at: now,
        start_char_index,
        end_char_index,
        selected_text,
        rects_json,
        strokes_json,
        note_content,
        note_rect_json,
    };

    create_annotation(annotation)
}
