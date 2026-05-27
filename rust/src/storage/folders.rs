// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use uuid::Uuid;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct FolderNode {
    pub id: String,
    pub name: String,
    pub children: Vec<FolderNode>,
    pub document_count: u32,
}

/// Creates a new folder and returns its UUID.
pub fn create_folder(name: String, parent_id: Option<String>) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    
    with_db(|conn| {
        conn.execute(
            "INSERT INTO folders (id, name, parent_id, created_at) VALUES (?, ?, ?, ?);",
            rusqlite::params![id, name, parent_id, created_at],
        )?;
        Ok(())
    })?;
    
    Ok(id)
}

/// Renames an existing folder.
pub fn rename_folder(id: String, new_name: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "UPDATE folders SET name = ? WHERE id = ?;",
            rusqlite::params![new_name, id],
        )?;
        Ok(())
    })
}

/// Deletes a folder. If `delete_documents` is true, deletes all documents inside
/// this folder and its subfolders from the database and deletes their physical sandbox files.
/// Otherwise, documents will have their folder_id set to NULL (moved to Unclassified).
pub fn delete_folder(id: String, delete_documents: bool) -> Result<(), String> {
    with_db(|conn| {
        if delete_documents {
            // Find all subfolder IDs (including the folder itself) using recursive CTE
            let mut stmt = conn.prepare(
                "WITH RECURSIVE subfolders(id) AS (
                    SELECT ? 
                    UNION ALL 
                    SELECT f.id FROM folders f INNER JOIN subfolders s ON f.parent_id = s.id
                )
                SELECT id FROM subfolders;"
            )?;
            let folder_ids: Vec<String> = stmt
                .query_map([&id], |row| row.get(0))?
                .collect::<Result<_, _>>()?;

            // Find all documents inside these folders
            let mut doc_stmt = conn.prepare(
                "SELECT id, file_path FROM documents WHERE folder_id IS NOT NULL AND folder_id IN (
                    SELECT value FROM json_each(?)
                );"
            )?;
            // Use JSON array to pass list of IDs
            let folder_ids_json = serde_json::to_string(&folder_ids).unwrap_or_default();
            
            let docs: Vec<(String, String)> = doc_stmt
                .query_map([folder_ids_json], |row| Ok((row.get(0)?, row.get(1)?)))?
                .collect::<Result<_, _>>()?;

            // Physically delete files and delete from DB
            for (_doc_id, path) in docs {
                let _ = std::fs::remove_file(&path);
            }
        }
        
        // Delete the parent folder. Foreign key cascades will delete child folders.
        // If delete_documents was false, documents will automatically set folder_id to NULL.
        // If delete_documents was true, we cascade delete folders, and then we delete the documents
        // whose folder_id became NULL during cascading? No, if we delete the folder, the documents' folder_id
        // becomes NULL, but they remain in the db. If we want to delete them, we should delete documents first.
        
        if delete_documents {
            // Delete documents whose folder_id belongs to the subfolder tree
            let mut stmt = conn.prepare(
                "WITH RECURSIVE subfolders(id) AS (
                    SELECT ? 
                    UNION ALL 
                    SELECT f.id FROM folders f INNER JOIN subfolders s ON f.parent_id = s.id
                )
                DELETE FROM documents WHERE folder_id IN (SELECT id FROM subfolders);"
            )?;
            stmt.execute([&id])?;
        }

        conn.execute("DELETE FROM folders WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// Builds and returns the hierarchical folder tree starting with a virtual "root" node.
pub fn get_folder_tree() -> Result<FolderNode, String> {
    with_db(|conn| {
        // Query all folders
        let mut stmt = conn.prepare("SELECT id, name, parent_id FROM folders ORDER BY name ASC;")?;
        let folders_raw: Vec<(String, String, Option<String>)> = stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)))?
            .collect::<Result<_, _>>()?;

        // Query document counts per folder
        let mut count_stmt = conn.prepare("SELECT folder_id, COUNT(*) FROM documents WHERE folder_id IS NOT NULL GROUP BY folder_id;")?;
        let counts: HashMap<String, u32> = count_stmt
            .query_map([], |row| Ok((row.get::<_, String>(0)?, row.get::<_, u32>(1)?)))?
            .collect::<Result<_, _>>()?;

        // Build the parent-child relationships map
        let mut parent_to_children: HashMap<Option<String>, Vec<(String, String)>> = HashMap::new();
        for (id, name, parent_id) in folders_raw {
            parent_to_children
                .entry(parent_id)
                .or_default()
                .push((id, name));
        }

        // Recursive helper to build subtrees
        fn build_node(
            id: String,
            name: String,
            parent_to_children: &HashMap<Option<String>, Vec<(String, String)>>,
            counts: &HashMap<String, u32>,
        ) -> FolderNode {
            let doc_count = *counts.get(&id).unwrap_or(&0);
            let mut children = Vec::new();
            if let Some(child_list) = parent_to_children.get(&Some(id.clone())) {
                for (child_id, child_name) in child_list {
                    children.push(build_node(
                        child_id.clone(),
                        child_name.clone(),
                        parent_to_children,
                        counts,
                    ));
                }
            }
            FolderNode {
                id,
                name,
                children,
                document_count: doc_count,
            }
        }

        // Build kids for root
        let mut root_children = Vec::new();
        if let Some(top_level) = parent_to_children.get(&None) {
            for (id, name) in top_level {
                root_children.push(build_node(
                    id.clone(),
                    name.clone(),
                    &parent_to_children,
                    &counts,
                ));
            }
        }

        // Count all documents that are in "Unclassified" (folder_id IS NULL)
        let unclassified_count: u32 = conn.query_row(
            "SELECT COUNT(*) FROM documents WHERE folder_id IS NULL;",
            [],
            |row| row.get(0),
        )?;

        Ok(FolderNode {
            id: "root".to_string(),
            name: "文件夹".to_string(),
            children: root_children,
            document_count: unclassified_count, // Root count represents Unclassified docs count in sidebar
        })
    })
}
