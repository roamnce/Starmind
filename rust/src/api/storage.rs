// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
use once_cell::sync::OnceCell;

// Re-export storage structures so that flutter_rust_bridge generates them
pub use crate::storage::folders::FolderNode;
pub use crate::storage::tags::TagNode;
pub use crate::storage::documents::DocumentInfo;
pub use crate::storage::annotations::{AnnotationRecord, AnnotationType, AnnotationRect, InkPoint, InkStroke};
pub use crate::storage::mindmap::{Topic, Note};
pub use crate::storage::ink_layers::InkLayerRecord;

static SANDBOX_DIR: OnceCell<String> = OnceCell::new();

/// Initializes the database connection and logs the sandbox path.
pub fn init_storage(db_path: String, sandbox_dir: String) -> Result<(), String> {
    // Initialize SQLite
    crate::storage::db::init_db(&db_path)?;

    // Initialize Sandbox directory path
    let _ = SANDBOX_DIR.set(sandbox_dir);

    Ok(())
}

/// Returns the complete hierarchical folder tree.
pub fn get_folder_tree() -> Result<FolderNode, String> {
    crate::storage::folders::get_folder_tree()
}

/// Creates a folder and returns its UUID.
pub fn create_folder(name: String, parent_id: Option<String>) -> Result<String, String> {
    crate::storage::folders::create_folder(name, parent_id)
}

/// Renames a folder.
pub fn rename_folder(id: String, new_name: String) -> Result<(), String> {
    crate::storage::folders::rename_folder(id, new_name)
}

/// Deletes a folder. If `delete_documents` is true, deletes all documents inside this folder
/// and its subfolders, physically removing their PDF files.
pub fn delete_folder(id: String, delete_documents: bool) -> Result<(), String> {
    crate::storage::folders::delete_folder(id, delete_documents)
}

/// Returns the complete hierarchical tag tree.
pub fn get_tag_tree() -> Result<TagNode, String> {
    crate::storage::tags::get_tag_tree()
}

/// Creates a tag and returns its UUID.
pub fn create_tag(
    name: String,
    parent_id: Option<String>,
    color_hex: Option<String>,
) -> Result<String, String> {
    crate::storage::tags::create_tag(name, parent_id, color_hex)
}

/// Renames a tag.
pub fn rename_tag(id: String, new_name: String) -> Result<(), String> {
    crate::storage::tags::rename_tag(id, new_name)
}

/// Deletes a tag.
pub fn delete_tag(id: String) -> Result<(), String> {
    crate::storage::tags::delete_tag(id)
}

/// Imports a PDF file, copying it into the sandboxed location.
pub fn import_pdf(
    title: String,
    source_path: String,
    folder_id: Option<String>,
) -> Result<String, String> {
    let sandbox = SANDBOX_DIR
        .get()
        .ok_or_else(|| "Sandbox directory has not been initialized. Call init_storage first.".to_string())?;

    crate::storage::documents::import_pdf(title, source_path, folder_id, sandbox.clone())
}

/// Deletes a document record and removes its physical sandboxed file.
pub fn delete_document(id: String) -> Result<(), String> {
    crate::storage::documents::delete_document(id)
}

/// Appends a tag to a document.
pub fn add_tag_to_document(doc_id: String, tag_id: String) -> Result<(), String> {
    crate::storage::documents::add_tag_to_document(doc_id, tag_id)
}

/// Removes a tag from a document.
pub fn remove_tag_from_document(doc_id: String, tag_id: String) -> Result<(), String> {
    crate::storage::documents::remove_tag_from_document(doc_id, tag_id)
}

/// Returns filtered, queried, and sorted list of documents.
pub fn get_documents(
    folder_id: Option<String>,
    tag_id: Option<String>,
    search_query: Option<String>,
    sort_by: String,
) -> Result<Vec<DocumentInfo>, String> {
    crate::storage::documents::get_documents(folder_id, tag_id, search_query, sort_by)
}

// ============== Annotation APIs ==============

/// Creates a new annotation and returns its ID.
pub fn create_annotation(annotation: AnnotationRecord) -> Result<String, String> {
    crate::storage::annotations::create_annotation(annotation)
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
    crate::storage::annotations::create_annotation_auto_id(
        document_id,
        page_index,
        annotation_type,
        is_standard,
        color_hex,
        start_char_index,
        end_char_index,
        selected_text,
        rects_json,
        strokes_json,
        note_content,
        note_rect_json,
    )
}

/// Gets all annotations for a document.
pub fn get_annotations(document_id: String) -> Result<Vec<AnnotationRecord>, String> {
    crate::storage::annotations::get_annotations(document_id)
}

/// Gets annotations for a specific page.
pub fn get_annotations_for_page(
    document_id: String,
    page_index: i32,
) -> Result<Vec<AnnotationRecord>, String> {
    crate::storage::annotations::get_annotations_for_page(document_id, page_index)
}

/// Updates an annotation.
pub fn update_annotation(id: String, updates: std::collections::HashMap<String, String>) -> Result<(), String> {
    crate::storage::annotations::update_annotation(id, updates)
}

/// Deletes an annotation.
pub fn delete_annotation(id: String) -> Result<(), String> {
    crate::storage::annotations::delete_annotation(id)
}

/// Deletes all annotations for a document.
pub fn delete_annotations_for_document(document_id: String) -> Result<(), String> {
    crate::storage::annotations::delete_annotations_for_document(document_id)
}

// ==================== MindMap FFI Functions ====================

/// Creates a mindmap topic (notebook)
pub fn mindmap_create_topic(title: String, author: Option<String>) -> Result<String, String> {
    crate::storage::mindmap::create_topic(title, author)
}

/// Gets a topic by ID
pub fn mindmap_get_topic(id: String) -> Result<Option<Topic>, String> {
    crate::storage::mindmap::get_topic_by_id(id)
}

/// Updates a topic
pub fn mindmap_update_topic(topic: Topic) -> Result<(), String> {
    crate::storage::mindmap::update_topic(topic)
}

/// Soft deletes a topic
pub fn mindmap_trash_topic(id: String) -> Result<(), String> {
    crate::storage::mindmap::trash_topic(id)
}

/// Gets all topics
pub fn mindmap_get_all_topics() -> Result<Vec<Topic>, String> {
    crate::storage::mindmap::get_all_topics()
}

/// Creates a mindmap note (node)
pub fn mindmap_create_note(
    topic_id: String,
    title: String,
    parent_id: Option<String>,
) -> Result<String, String> {
    crate::storage::mindmap::create_note(topic_id, title, parent_id)
}

/// Gets a note by ID
pub fn mindmap_get_note(id: String) -> Result<Option<Note>, String> {
    crate::storage::mindmap::get_note_by_id(id)
}

/// Updates a note
pub fn mindmap_update_note(note: Note) -> Result<(), String> {
    crate::storage::mindmap::update_note(note)
}

/// Deletes a note
pub fn mindmap_delete_note(id: String) -> Result<(), String> {
    crate::storage::mindmap::delete_note(id)
}

/// Adds a child to a note (pipe-separated append)
pub fn mindmap_add_child(parent_id: String, child_id: String) -> Result<(), String> {
    crate::storage::mindmap::add_child_to_note(parent_id, child_id)
}

/// Removes a child from a note
pub fn mindmap_remove_child(parent_id: String, child_id: String) -> Result<(), String> {
    crate::storage::mindmap::remove_child_from_note(parent_id, child_id)
}

/// Gets children of a note
pub fn mindmap_get_children(parent_id: String) -> Result<Vec<Note>, String> {
    crate::storage::mindmap::get_note_children(parent_id)
}

/// Gets notes by PDF ID
pub fn mindmap_get_notes_by_pdf(pdf_id: String) -> Result<Vec<Note>, String> {
    crate::storage::mindmap::get_notes_by_pdf(pdf_id)
}

/// Gets notes by topic ID
pub fn mindmap_get_notes_by_topic(topic_id: String) -> Result<Vec<Note>, String> {
    crate::storage::mindmap::get_notes_by_topic(topic_id)
}

// ============== MindMap Ink Layer APIs ==============

pub fn mindmap_save_ink_layer(layer: InkLayerRecord) -> Result<String, String> {
    crate::storage::ink_layers::save_ink_layer(layer)
}

pub fn mindmap_get_ink_layer(owner_id: String, layer_type: String) -> Result<Option<InkLayerRecord>, String> {
    crate::storage::ink_layers::get_ink_layer(owner_id, layer_type)
}

pub fn mindmap_delete_ink_layer(id: String) -> Result<(), String> {
    crate::storage::ink_layers::delete_ink_layer(id)
}
