<!-- 🤖 Generated wholly or partially with Gemini Code; Google Antigravity -->
# Starmind Domain Glossary (CONTEXT.md)

This document defines the canonical domain terms used within the Starmind project to ensure consistency between the code (both Flutter and Rust) and the project documentation.

---

## Glossary of Terms

### Document (文档)
*   **Definition**: A PDF book, paper, or reading material imported by the user into Starmind.
*   **Properties**:
    *   It is physically copied into the app's secure sandboxed storage during import.
    *   It is represented as a record in the SQLite database containing its unique ID, local title, copied file path, and parent Folder ID.
*   **Rules**:
    *   A Document can belong to at most one Folder. If it has no Folder, it is considered **Unclassified (未分类)**.
    *   A Document can be associated with multiple Tags.

### Folder (文件夹)
*   **Definition**: A hierarchical container used to categorize Documents.
*   **Properties**:
    *   Supports a tree structure via a `parent_id` reference (enabling infinite nested folders).
    *   Contains subfolders and/or Documents.
*   **Rules**:
    *   Deleting a Folder triggers a prompt asking the user whether to **keep** the documents (moving them to "Unclassified") or **cascade-delete** them (moving documents and subfolders into the Trash Bin).

### Tag (标签)
*   **Definition**: A cross-dimensional metadata label applied to Documents (and in future phases, to Excerpt Cards).
*   **Properties**:
    *   Supports a hierarchical tree structure via a `parent_id` reference (e.g., "Learning -> Programming -> Flutter").
    *   Can have custom styles like `color_hex`.
*   **Rules**:
    *   A single Document can have multiple Tags associated with it via a many-to-many relationship.
    *   A Tag can be associated with multiple Documents.

### Workspace (工作区)
*   **Definition**: The primary multi-tab container where users manage and view their learning materials.
*   **Properties**:
    *   Maintains a tab list where the first tab is always a permanent, non-closable **Dashboard (首页)**.
    *   Supports opening multiple Documents in different tabs.
    *   Tracks user's active tab index and view history.

### Split Panel (分屏面板)
*   **Definition**: The structural layout element in the Workspace UI that enables recursive vertical or horizontal viewport splitting.
*   **Properties**:
    *   Represented as a tree structure (Split Tree) where each node is either a `Parent` node (splitting its space horizontally or vertically into child nodes) or a `Leaf` node (rendering a Tab Bar and its active page).
    *   Allows dragging tabs from one panel to another to trigger dynamic screen-splitting, supporting arbitrary side-by-side configurations (e.g., Home + PDF, PDF + PDF, PDF + Mind Map).

### Annotation (批注)
*   **Definition**: User-created marks or notes attached to specific locations within a Document.
*   **Categories**:
    *   **Standard Annotation (标准批注)**: Annotations exported as PDF native annotation objects, recognizable and editable by other PDF readers.
        *   Includes: Text Highlight (文本高亮), Text Underline (文本下划线).
        *   After export: Can be selected, deleted, or modified in apps like WPS, Adobe Reader, etc.
    *   **Private Annotation (私有批注)**: Starmind-specific annotations, exported as rendered content (images/vector graphics), not recognizable as annotations by other PDF readers.
        *   Includes: Handwriting Note (手写笔记), Text Wave Line (文本波浪线), Text Note (文本笔记).
        *   After export: Appears as static visual content on the page; cannot be edited by other readers.
*   **Properties**:
    *   All annotations are primarily stored in SQLite for optimal editing performance.
    *   All annotation types can be exported when creating a PDF copy—standard annotations become native PDF objects, private annotations become rendered graphics.
    *   Associated with a specific Document and Page Index.
    *   Contains position data (character indices for text-based annotations, stroke points for handwriting).
*   **Rules**:
    *   Annotations are created during reading sessions and persisted across sessions.
    *   Undo/Redo operates on a document-level stack shared with other operations (zoom, scroll, etc.).
    *   Export to PDF copy is a manual, non-destructive operation—the original PDF remains unchanged.
*   **Export Behavior Summary**:
    | Annotation Type | Exported Form | Editable in Other Readers |
    |----------------|---------------|---------------------------|
    | Text Highlight | PDF native highlight annotation | ✅ Yes |
    | Text Underline | PDF native underline annotation | ✅ Yes |
    | Text Wave Line | Rendered wave line graphic | ❌ No (static image) |
    | Handwriting Note | Rendered stroke paths | ❌ No (static image) |
    | Text Note | Rendered text or popup note | Partial (depends on export mode) |
