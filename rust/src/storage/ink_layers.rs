use crate::storage::db::with_db;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InkLayerRecord {
    pub id: String,
    pub layer_type: String,
    pub owner_id: String,
    pub strokes_json: String,
    pub z_index: i32,
    pub created_at: i64,
    pub updated_at: i64,
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}

pub fn save_ink_layer(mut layer: InkLayerRecord) -> Result<String, String> {
    if layer.id.is_empty() {
        layer.id = format!("ink-{}", Uuid::new_v4());
    }
    let now = now_ms();
    if layer.created_at <= 0 {
        layer.created_at = now;
    }
    layer.updated_at = now;

    with_db(|conn| {
        conn.execute(
            r#"
            INSERT INTO ink_layers (id, type, owner_id, strokes_json, z_index, created_at, updated_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
            ON CONFLICT(owner_id, type) DO UPDATE SET
                strokes_json = excluded.strokes_json,
                z_index = excluded.z_index,
                updated_at = excluded.updated_at
            "#,
            rusqlite::params![
                layer.id,
                layer.layer_type,
                layer.owner_id,
                layer.strokes_json,
                layer.z_index,
                layer.created_at,
                layer.updated_at,
            ],
        )?;
        Ok(layer.id)
    })
}

pub fn get_ink_layer(owner_id: String, layer_type: String) -> Result<Option<InkLayerRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            r#"
            SELECT id, type, owner_id, strokes_json, z_index, created_at, updated_at
            FROM ink_layers
            WHERE owner_id = ?1 AND type = ?2
            "#,
        )?;
        let mut rows = stmt.query(rusqlite::params![owner_id, layer_type])?;
        if let Some(row) = rows.next()? {
            Ok(Some(InkLayerRecord {
                id: row.get(0)?,
                layer_type: row.get(1)?,
                owner_id: row.get(2)?,
                strokes_json: row.get(3)?,
                z_index: row.get(4)?,
                created_at: row.get(5)?,
                updated_at: row.get(6)?,
            }))
        } else {
            Ok(None)
        }
    })
}

pub fn delete_ink_layer(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM ink_layers WHERE id = ?1", rusqlite::params![id])?;
        Ok(())
    })
}
