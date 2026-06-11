import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/dialogs/glass_dialogs.dart';

/// Shows the PDF import dialog.
void showImportPdfDialog(
  BuildContext context,
  WorkspaceController workspaceController,
) {
  final isDark = workspaceController.isDarkMode;
  String? folderId = workspaceController.activeFolderFilter;

  // If active filter is "all" or "unclassified" or tag filters, import to null (Unclassified)
  if (folderId == 'all' || folderId == 'unclassified') {
    folderId = null;
  }

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFFFC800),
                ),
                const SizedBox(width: 10),
                Text(
                  '导入 PDF 文件',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => handlePdfFileSelection(
                context,
                folderId,
                workspaceController,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x33FFC800),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  color: isDark
                      ? const Color(0x0CFFC800)
                      : const Color(0x05FFC800),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Color(0xFFFFC800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '选择并导入 PDF 文件',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '文件将被物理拷贝至 App 沙盒目录内',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Handles PDF file selection and import.
Future<void> handlePdfFileSelection(
  BuildContext context,
  String? folderId,
  WorkspaceController workspaceController,
) async {
  // Close selection dialog first
  Navigator.pop(context);

  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result == null || result.files.single.path == null) return;

  final filePath = result.files.single.path!;
  final fileName = result.files.single.name;
  final defaultTitle = fileName.replaceAll(
    RegExp(r'\.pdf$', caseSensitive: false),
    '',
  );

  if (!context.mounted) return;

  // Pop up title confirm dialog
  final titleController = TextEditingController(text: defaultTitle);
  final isDark = workspaceController.isDarkMode;

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '确认文档标题',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(context); // Close title dialog

                    // Show loader dialog during copy
                    showLoaderDialog(context, isDark);

                    try {
                      await workspaceController.importPdfFile(
                        title,
                        filePath,
                        folderId,
                      );
                    } catch (e) {
                      debugPrint('Import PDF failed: $e');
                    } finally {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loader
                      }
                    }
                  },
                  child: const Text('开始导入'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a loading dialog with progress indicator.
void showLoaderDialog(BuildContext context, bool isDark) {
  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFC800)),
            const SizedBox(height: 18),
            Text(
              '正在拷贝至沙盒目录...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}