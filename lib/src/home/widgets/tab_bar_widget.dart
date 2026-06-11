import 'package:flutter/material.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';

/// Top tab bar widget for workspace tabs.
class TabBarWidget extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const TabBarWidget({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;
    const double leftSpacerWidth = 12.0;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC0E0B06) : const Color(0xFFEFECE6),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Padding to account for floating control buttons on the left
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            width: leftSpacerWidth,
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, idx) {
                final tab = tabs[idx];
                final isActive = idx == activeIndex;

                return GestureDetector(
                  onTap: () => onSelect(idx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 7,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark
                                ? const Color(0x2E6B3A08)
                                : const Color(0x1F6B3A08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isActive
                            ? (isDark
                                  ? const Color(0x4DC8841A)
                                  : const Color(0x33C8841A))
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.type == TabType.home
                              ? Icons.home_rounded
                              : Icons.picture_as_pdf_rounded,
                          size: 13,
                          color: isActive
                              ? const Color(0xFFFFC800)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? const Color(0xFFFFF8E6)
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (tab.type != TabType.home) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              onClose(idx);
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Split Pane placeholder button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Tooltip(
              message: '双联分屏(敬请期待)',
              child: Icon(
                Icons.vertical_split_rounded,
                size: 15,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}