import 'package:flutter/material.dart';

/// Data model for context menu items.
class ContextMenuItem {
  final String title;
  final IconData? icon;
  final bool isDanger;
  final VoidCallback onTap;

  ContextMenuItem({
    required this.title,
    this.icon,
    this.isDanger = false,
    required this.onTap,
  });
}