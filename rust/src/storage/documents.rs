// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct DocumentInfo {
    pub id: String,
    pub title: String,
    pub file_path: String,
    pub folder_id: Option<String>,
    pub tag_ids: Vec<String>,
    pub created_at: i64,
}

/// Imports a PDF document. Copies the original file from `source_path` into `sandbox_dir`
/// as `{uuid}.pdf`, and inserts a record in the SQLite database.
pub fn import_pdf(
    title: String,
    source_path: String,
    folder_id: Option<String>,
    sandbox_dir: String,
) -> Result<String, String> {
    // 1. Generate UUID
    let id = Uuid::new_v4().to_string();
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    // 2. Resolve destination path
    let sandbox_path = std::path::Path::new(&sandbox_dir);
    if !sandbox_path.exists() {
        std::fs::create_dir_all(sandbox_path)
            .map_err(|e| format!("Failed to create sandbox directory: {}", e))?;
    }
    
    let dest_filename = format!("{}.pdf", id);
    let dest_path = sandbox_path.join(dest_filename);
    let dest_path_str = dest_path.to_str()
        .ok_or_else(|| "Invalid target UTF-8 path".to_string())?
        .to_string();

    // 3. Copy file
    std::fs::copy(&source_path, &dest_path)
        .map_err(|e| format!("Failed to copy file from {} to {}: {}", source_path, dest_path_str, e))?;

    // 4. Save to DB. If folder_id is some special keywords (e.g. "unclassified"), save as NULL
    let db_folder_id = match folder_id {
        Some(ref f_id) if f_id == "unclassified" || f_id.is_empty() => None,
        other => other,
    };

    with_db(|conn| {
        conn.execute(
            "INSERT INTO documents (id, title, file_path, folder_id, created_at) VALUES (?, ?, ?, ?, ?);",
            rusqlite::params![id, title, dest_path_str, db_folder_id, created_at],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Deletes a document from the database and removes its physical sandboxed file.
pub fn delete_document(id: String) -> Result<(), String> {
    // Find path first
    let path: String = with_db(|conn| {
        conn.query_row(
            "SELECT file_path FROM documents WHERE id = ?;",
            [&id],
            |row| row.get(0),
        )
    })?;

    // Remove physical file
    let _ = std::fs::remove_file(&path);

    // Delete record (cascading deletes document_tags table records)
    with_db(|conn| {
        conn.execute("DELETE FROM documents WHERE id = ?;", [&id])?;
        Ok(())
    })
}

/// Binds a tag to a document.
pub fn add_tag_to_document(doc_id: String, tag_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "INSERT OR IGNORE INTO document_tags (document_id, tag_id) VALUES (?, ?);",
            rusqlite::params![doc_id, tag_id],
        )?;
        Ok(())
    })
}

/// Unbinds a tag from a document.
pub fn remove_tag_from_document(doc_id: String, tag_id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "DELETE FROM document_tags WHERE document_id = ? AND tag_id = ?;",
            rusqlite::params![doc_id, tag_id],
        )?;
        Ok(())
    })
}

/// Fetches documents with dynamic filters, query search, and sorting.
pub fn get_documents(
    folder_id: Option<String>,
    tag_id: Option<String>,
    search_query: Option<String>,
    sort_by: String, // "modified" | "created" | "name"
) -> Result<Vec<DocumentInfo>, String> {
    with_db(|conn| {
        let mut query_parts = vec!["SELECT id, title, file_path, folder_id, created_at FROM documents".to_string()];
        let mut filters = vec![];
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = vec![];

        // 1. Folder filter
        if let Some(ref f_id) = folder_id {
            if f_id == "unclassified" {
                filters.push("folder_id IS NULL".to_string());
            } else if !f_id.is_empty() && f_id != "all" {
                // To support nested folders, we should optionally select all child folders too,
                // but since a document belongs strictly to its folder_id, we can either do exact matches
                // or match folder_id in subfolder tree. Let's do exact match for simplicity first.
                filters.push("folder_id = ?".to_string());
                params.push(Box::new(f_id.clone()));
            }
        }

        // 2. Tag filter
        if let Some(ref t_id) = tag_id {
            if t_id == "untagged" {
                filters.push("id NOT IN (SELECT DISTINCT document_id FROM document_tags)".to_string());
            } else if !t_id.is_empty() && t_id != "all" {
                filters.push("id IN (SELECT document_id FROM document_tags WHERE tag_id = ?)".to_string());
                params.push(Box::new(t_id.clone()));
            }
        }

        // 3. Search query
        if let Some(ref search) = search_query {
            if !search.is_empty() {
                filters.push("title LIKE ?".to_string());
                params.push(Box::new(format!("%{}%", search)));
            }
        }

        if !filters.is_empty() {
            query_parts.push("WHERE".to_string());
            query_parts.push(filters.join(" AND "));
        }

        // 4. Sorting
        let order_clause = match sort_by.as_str() {
            "name" => "ORDER BY title ASC",
            "created" | "modified" | _ => "ORDER BY created_at DESC",
        };
        query_parts.push(order_clause.to_string());

        let final_query = query_parts.join(" ");
        let mut stmt = conn.prepare(&final_query)?;

        // Map params to slice of references
        let params_refs: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p.as_ref()).collect();
        let docs_raw: Vec<(String, String, String, Option<String>, i64)> = stmt
            .query_map(&params_refs[..], |row| {
                Ok((
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            })?
            .collect::<Result<_, _>>()?;

        // 5. Gather tags for each document
        let mut tag_stmt = conn.prepare("SELECT tag_id FROM document_tags WHERE document_id = ?;")?;
        
        let mut result = Vec::new();
        for (id, title, file_path, f_id, created_at) in docs_raw {
            let tags: Vec<String> = tag_stmt
                .query_map([&id], |row| row.get(0))?
                .collect::<Result<_, _>>()?;
                
            result.push(DocumentInfo {
                id,
                title,
                file_path,
                folder_id: f_id,
                tag_ids: tags,
                created_at,
            });
        }

        Ok(result)
    })
}
