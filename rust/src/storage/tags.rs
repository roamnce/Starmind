// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use crate::storage::db::with_db;
use uuid::Uuid;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct TagNode {
    pub id: String,
    pub name: String,
    pub children: Vec<TagNode>,
    pub color_hex: Option<String>,
    pub document_count: u32,
}

/// Creates a new tag and returns its UUID.
pub fn create_tag(
    name: String,
    parent_id: Option<String>,
    color_hex: Option<String>,
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let created_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    with_db(|conn| {
        conn.execute(
            "INSERT INTO tags (id, name, parent_id, color_hex, created_at) VALUES (?, ?, ?, ?, ?);",
            rusqlite::params![id, name, parent_id, color_hex, created_at],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Renames an existing tag.
pub fn rename_tag(id: String, new_name: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute(
            "UPDATE tags SET name = ? WHERE id = ?;",
            rusqlite::params![new_name, id],
        )?;
        Ok(())
    })
}

/// Deletes a tag. Foreign key cascade deletes child tags and document_tags associations.
pub fn delete_tag(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM tags WHERE id = ?;", rusqlite::params![id])?;
        Ok(())
    })
}

/// Builds and returns the hierarchical tag tree starting with a virtual "root" node.
pub fn get_tag_tree() -> Result<TagNode, String> {
    with_db(|conn| {
        // Query all tags
        let mut stmt = conn.prepare("SELECT id, name, parent_id, color_hex FROM tags ORDER BY name ASC;")?;
        let tags_raw: Vec<(String, String, Option<String>, Option<String>)> = stmt
            .query_map([], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?))
            })?
            .collect::<Result<_, _>>()?;

        // Query document counts per tag
        let mut count_stmt = conn.prepare("SELECT tag_id, COUNT(*) FROM document_tags GROUP BY tag_id;")?;
        let counts: HashMap<String, u32> = count_stmt
            .query_map([], |row| Ok((row.get::<_, String>(0)?, row.get::<_, u32>(1)?)))?
            .collect::<Result<_, _>>()?;

        // Build the parent-child relationships map
        let mut parent_to_children: HashMap<
            Option<String>,
            Vec<(String, String, Option<String>)>,
        > = HashMap::new();
        for (id, name, parent_id, color_hex) in tags_raw {
            parent_to_children
                .entry(parent_id)
                .or_default()
                .push((id, name, color_hex));
        }

        // Recursive helper to build subtrees
        fn build_node(
            id: String,
            name: String,
            color_hex: Option<String>,
            parent_to_children: &HashMap<Option<String>, Vec<(String, String, Option<String>)>>,
            counts: &HashMap<String, u32>,
        ) -> TagNode {
            let doc_count = *counts.get(&id).unwrap_or(&0);
            let mut children = Vec::new();
            if let Some(child_list) = parent_to_children.get(&Some(id.clone())) {
                for (child_id, child_name, child_color) in child_list {
                    children.push(build_node(
                        child_id.clone(),
                        child_name.clone(),
                        child_color.clone(),
                        parent_to_children,
                        counts,
                    ));
                }
            }
            TagNode {
                id,
                name,
                children,
                color_hex,
                document_count: doc_count,
            }
        }

        // Build kids for root
        let mut root_children = Vec::new();
        if let Some(top_level) = parent_to_children.get(&None) {
            for (id, name, color_hex) in top_level {
                root_children.push(build_node(
                    id.clone(),
                    name.clone(),
                    color_hex.clone(),
                    &parent_to_children,
                    &counts,
                ));
            }
        }

        // Count all documents that have no tags assigned
        let untagged_count: u32 = conn.query_row(
            "SELECT COUNT(*) FROM documents WHERE id NOT IN (SELECT DISTINCT document_id FROM document_tags);",
            [],
            |row| row.get(0),
        )?;

        Ok(TagNode {
            id: "root".to_string(),
            name: "标签".to_string(),
            children: root_children,
            color_hex: None,
            document_count: untagged_count, // Root count represents Untagged docs count in sidebar
        })
    })
}
