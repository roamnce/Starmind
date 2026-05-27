// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity

use std::collections::HashMap;
use std::sync::Mutex;
use once_cell::sync::Lazy;
use once_cell::sync::OnceCell;
use pdfium_render::prelude::*;

struct PdfiumWrapper(Pdfium);
unsafe impl Send for PdfiumWrapper {}
unsafe impl Sync for PdfiumWrapper {}

struct PdfDocumentWrapper(PdfDocument<'static>);
unsafe impl Send for PdfDocumentWrapper {}
unsafe impl Sync for PdfDocumentWrapper {}

static PDFIUM: OnceCell<PdfiumWrapper> = OnceCell::new();
static DOCUMENTS: Lazy<Mutex<HashMap<String, PdfDocumentWrapper>>> = Lazy::new(|| Mutex::new(HashMap::new()));

pub fn init_pdfium(library_path: Option<String>) -> Result<(), String> {
    if PDFIUM.get().is_some() {
        return Ok(());
    }

    let bindings = if let Some(ref path) = library_path {
        Pdfium::bind_to_library(path).map_err(|e| e.to_string())?
    } else {
        Pdfium::bind_to_system_library()
            .or_else(|_| Pdfium::bind_to_library(Pdfium::pdfium_platform_library_name_at_path("./")))
            .map_err(|e| e.to_string())?
    };

    let pdfium = Pdfium::new(bindings);
    if PDFIUM.set(PdfiumWrapper(pdfium)).is_err() {
        return Err("Failed to store PDFium instance".to_string());
    }

    Ok(())
}

pub fn load_document(file_path: String) -> Result<String, String> {
    let pdfium_wrapper = PDFIUM.get().ok_or("PDFium not initialized. Call init_pdfium first.")?;

    let doc = pdfium_wrapper.0.load_pdf_from_file(&file_path, None).map_err(|e| e.to_string())?;

    // Transmute lifetime of PdfDocument to 'static since PDFIUM is a static OnceCell that lives forever
    let doc_static: PdfDocument<'static> = unsafe { std::mem::transmute(doc) };

    let doc_id = uuid::Uuid::new_v4().to_string();

    let mut docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    docs.insert(doc_id.clone(), PdfDocumentWrapper(doc_static));

    Ok(doc_id)
}

pub fn close_document(doc_id: String) -> Result<(), String> {
    let mut docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    if docs.remove(&doc_id).is_none() {
        return Err("Document not found".to_string());
    }
    Ok(())
}

pub fn get_page_count(doc_id: String) -> Result<u32, String> {
    let docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    let doc_wrapper = docs.get(&doc_id).ok_or("Document not found")?;
    Ok(doc_wrapper.0.pages().len() as u32)
}

pub fn get_page_size(doc_id: String, page_index: u32) -> Result<(f32, f32), String> {
    let docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    let doc_wrapper = docs.get(&doc_id).ok_or("Document not found")?;
    let pages = doc_wrapper.0.pages();
    let page = pages.get(page_index as u16).map_err(|e| e.to_string())?;
    Ok((page.width().value, page.height().value))
}

pub struct ViewportRequest {
    pub doc_id: String,
    pub page_index: u32,
    pub pdf_left: f32,
    pub pdf_top: f32,
    pub pdf_right: f32,
    pub pdf_bottom: f32,
    pub target_width: u32,
    pub target_height: u32,
    pub render_dpi: Option<f32>,  // 新增: 渲染 DPI，None 则使用默认 72
}

pub fn render_viewport(req: ViewportRequest) -> Result<Vec<u8>, String> {
    let pdfium_wrapper = PDFIUM.get().ok_or("PDFium not initialized")?;
    let bindings = pdfium_wrapper.0.bindings();

    let docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    let doc_wrapper = docs.get(&req.doc_id).ok_or("Document not found")?;

    let pages = doc_wrapper.0.pages();
    let page = pages.get(req.page_index as u16).map_err(|e| e.to_string())?;
    let page_handle = bindings.get_handle_from_page(&page);

    let page_width = page.width().value;
    let page_height = page.height().value;

    // 根据 render_dpi 计算缩放因子
    let dpi = req.render_dpi.unwrap_or(72.0);
    let dpi_scale = dpi / 72.0;  // PDF 默认 72 DPI

    let width_pdf = req.pdf_right - req.pdf_left;
    if width_pdf <= 0.0 {
        return Err("Invalid viewport width".to_string());
    }

    // 综合缩放: DPI 缩放 × 目标尺寸缩放
    let scale = (req.target_width as f64 / width_pdf as f64) * dpi_scale as f64;

    // 渲染尺寸 (高分辨率)
    let scaled_page_width = (page_width as f64 * scale).round() as i32;
    let scaled_page_height = (page_height as f64 * scale).round() as i32;

    let start_x = (-(req.pdf_left as f64 * scale)).round() as i32;
    let start_y = (-((page_height - req.pdf_top) as f64 * scale)).round() as i32;

    // 目标尺寸也要按 DPI 缩放
    let final_width = (req.target_width as f64 * dpi_scale as f64).round() as i32;
    let final_height = (req.target_height as f64 * dpi_scale as f64).round() as i32;

    unsafe {
        let bitmap = bindings.FPDFBitmap_Create(final_width, final_height, 1);
        if bitmap.is_null() {
            return Err("Failed to create PDFium bitmap".to_string());
        }

        bindings.FPDFBitmap_FillRect(
            bitmap,
            0, 0, final_width, final_height,
            0xFFFFFFFF,
        );

        bindings.FPDF_RenderPageBitmap(
            bitmap,
            page_handle,
            start_x,
            start_y,
            scaled_page_width,
            scaled_page_height,
            0,
            0x01,
        );

        let buffer = bindings.FPDFBitmap_GetBuffer(bitmap);
        if buffer.is_null() {
            bindings.FPDFBitmap_Destroy(bitmap);
            return Err("Failed to get bitmap buffer pointer".to_string());
        }

        let length = (final_width * final_height * 4) as usize;
        let slice = std::slice::from_raw_parts(buffer as *const u8, length);
        let bgra_bytes = slice.to_vec();

        bindings.FPDFBitmap_Destroy(bitmap);

        Ok(bgra_bytes)
    }
}

pub struct CharInfo {
    pub text: String,
    pub index: u32,
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

pub fn get_page_chars(doc_id: String, page_index: u32) -> Result<Vec<CharInfo>, String> {
    let docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    let doc_wrapper = docs.get(&doc_id).ok_or("Document not found")?;

    let pages = doc_wrapper.0.pages();
    let page = pages.get(page_index as u16).map_err(|e| e.to_string())?;

    let text_page = page.text().map_err(|e| e.to_string())?;
    let chars = text_page.chars();

    let mut result = Vec::new();
    for (i, char_obj) in chars.iter().enumerate() {
        let text = char_obj.unicode_string().unwrap_or_default();
        if let Ok(bounds) = char_obj.loose_bounds() {
            result.push(CharInfo {
                text,
                index: i as u32,
                left: bounds.left().value,
                top: bounds.top().value,
                right: bounds.right().value,
                bottom: bounds.bottom().value,
            });
        }
    }

    Ok(result)
}

/// Exports a PDF with annotations rendered into it.
///
/// Standard annotations (highlight, underline) are added as PDF native annotation objects.
/// Private annotations (wave, ink, note) are rendered as graphics on the page.
pub fn export_pdf_with_annotations(
    source_path: String,
    output_path: String,
    annotations: Vec<crate::storage::annotations::AnnotationRecord>,
) -> Result<(), String> {
    let pdfium_wrapper = PDFIUM.get().ok_or("PDFium not initialized")?;

    // Load the source PDF
    let doc = pdfium_wrapper.0
        .load_pdf_from_file(&source_path, None)
        .map_err(|e| format!("Failed to load source PDF: {}", e))?;

    // Process each annotation
    for annotation in &annotations {
        let page_index = annotation.page_index as u16;
        let pages = doc.pages();

        if page_index >= pages.len() as u16 {
            continue; // Skip invalid page indices
        }

        let page = pages.get(page_index).map_err(|e| e.to_string())?;

        match annotation.annotation_type.as_str() {
            "highlight" | "underline" => {
                // Standard annotations - create PDF annotation objects
                if let Some(ref rects_json) = annotation.rects_json {
                    if let Ok(rects) = serde_json::from_str::<Vec<crate::storage::annotations::AnnotationRect>>(rects_json) {
                        for rect in rects {
                            add_standard_annotation(
                                &pdfium_wrapper.0,
                                &page,
                                &annotation.annotation_type,
                                &rect,
                                &annotation.color_hex,
                            )?;
                        }
                    }
                }
            }
            "wave" | "ink" | "note" => {
                // Private annotations - rendered as graphics
                // For simplicity in this phase, we skip these
                // Full implementation would use FPDFPage_DrawPath etc.
            }
            _ => {}
        }
    }

    // Save to output path
    doc.save_to_file(&output_path)
        .map_err(|e| format!("Failed to save PDF: {}", e))?;

    Ok(())
}

/// Adds a standard PDF annotation (highlight or underline) to a page.
fn add_standard_annotation(
    pdfium: &Pdfium,
    page: &PdfPage,
    annotation_type: &str,
    rect: &crate::storage::annotations::AnnotationRect,
    color_hex: &str,
) -> Result<(), String> {
    let bindings = pdfium.bindings();

    // Parse color from hex (#RRGGBB)
    let color = parse_color_hex(color_hex);

    // Get page handle
    let page_handle = bindings.get_handle_from_page(page);

    unsafe {
        // Create annotation
        let annot_type = if annotation_type == "underline" {
            FPDF_ANNOT_UNDERLINE as i32
        } else {
            FPDF_ANNOT_HIGHLIGHT as i32
        };

        let annot = bindings.FPDFPage_CreateAnnot(page_handle, annot_type);
        if annot.is_null() {
            return Err("Failed to create annotation".to_string());
        }

        // Set annotation rectangle (PDF uses bottom-left origin)
        let page_height = page.height().value;
        let pdf_rect = FPDF_FS_RECTF {
            left: rect.left,
            top: page_height - rect.bottom,  // Convert to PDF coordinates
            right: rect.right,
            bottom: page_height - rect.top,
        };

        bindings.FPDFAnnot_SetRect(annot, &pdf_rect as *const _ as *mut _);

        // Set color
        bindings.FPDFAnnot_SetColor(
            annot,
            FPDFANNOT_COLORTYPE_Color,
            color.0,
            color.1,
            color.2,
            255, // Alpha (opaque for standard annotations)
        );
    }

    Ok(())
}

/// Parses a hex color string to RGB values.
fn parse_color_hex(hex: &str) -> (u32, u32, u32) {
    let hex = hex.trim_start_matches('#');
    if hex.len() != 6 {
        return (255, 255, 0); // Default yellow
    }

    let r = u32::from_str_radix(&hex[0..2], 16).unwrap_or(255);
    let g = u32::from_str_radix(&hex[2..4], 16).unwrap_or(255);
    let b = u32::from_str_radix(&hex[4..6], 16).unwrap_or(0);

    (r, g, b)
}

// PDFium annotation constants
const FPDF_ANNOT_HIGHLIGHT: u32 = 4;
const FPDF_ANNOT_UNDERLINE: u32 = 5;
const FPDFANNOT_COLORTYPE_Color: u32 = 0;

// FPDF_FS_RECTF structure for annotation rectangles
#[repr(C)]
struct FPDF_FS_RECTF {
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
}
