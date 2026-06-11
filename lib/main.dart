/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'package:flutter/material.dart';
import 'package:starmind/src/rust/frb_generated.dart';
import 'package:starmind/src/domain/ffi_storage_repository.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/home/workspace_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the Rust library (PDFium will be initialized by Rust's pdfium-render, not pdfrx)
  await RustLib.init();

  // Initialize workspace controller with explicit dependency injection
  final workspaceController = WorkspaceController(FfiStorageRepository());
  await workspaceController.init();

  runApp(
    WorkspaceControllerProvider(
      controller: workspaceController,
      child: const MyApp(),
    ),
  );
}

// Global navigator key for accessing context outside of widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.workspaceController,
      builder: (context, _) {
        final controller = context.workspaceController;
        final isDark = controller.isDarkMode;

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'StarMind',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFC800), // Vibrant saber gold
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: isDark
                  ? const Color(0xFF0C0A07)
                  : const Color(0xFFFAF9F6),
            ),
            useMaterial3: true,
            fontFamily: 'AtkinsonHyperlegibleNext',
          ),
          home: const WorkspacePage(),
        );
      },
    );
  }
}