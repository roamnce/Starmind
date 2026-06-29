// lib/src/mindmap/ui/cards/live_preview/live_preview_controller.dart
//
// Obsidian Live Preview 风格的 [TextEditingController]。
//
// 设计取舍
// - **源码字符保留**：所有 markdown 符号（`#`、`**`、`` ` `` 等）都不
//   从 [TextSpan] 中删除，避免 Flutter `EditableText` 选区/光标错位。
// - **视觉上淡化**：语法符号用极低不透明度的灰色绘制，看起来像不存在。
// - **正文按最终样式绘制**：标题字号变大且加粗、`**bold**` 中的 `bold`
//   真正以粗体绘制、`*italic*` 真正斜体、`` `code` `` 真正等宽并带背景、
//   `[text](url)` 中 `text` 加下划线，`(url)` 同样淡化。
// - **长度不变量**：所有 TextSpan 的 text 拼接后必须等于 controller.text，
//   否则 Flutter 选区矩形会错位（marktext-plus 的同名 controller 也有这条
//   防御性检查）。

import 'package:flutter/material.dart';

/// 一个能把原始 markdown 文本实时绘制成富文本预览的
/// [TextEditingController]。
///
/// 与之前的语法高亮 controller 不同之处：
/// - 标题行**整行**用 `fontSize: 28..14` 真正放大并加粗。
/// - `**bold**` 中间的实体文字使用 `FontWeight.bold` 绘制，**符号本身淡化**。
/// - `*italic*` 中间使用 `FontStyle.italic`。
/// - `` `code` `` 中间使用等宽字体并加浅色背景。
/// - `[text](url)` 中 `text` 加下划线，url 与方括号淡化。
/// - 删除线 `~~text~~` 使用 `TextDecoration.lineThrough`。
class LivePreviewController extends TextEditingController {
  /// 标题文字颜色。
  Color headingColor;

  /// 正文颜色。
  Color textColor;

  /// 强调（粗体）颜色。
  Color boldColor;

  /// 斜体颜色。
  Color italicColor;

  /// 行内代码前景色。
  Color codeColor;

  /// 链接颜色。
  Color linkColor;

  /// 删除线颜色。
  Color strikeColor;

  /// 语法符号颜色（被淡化）。
  Color syntaxColor;

  /// 行内代码背景色。
  Color codeBg;

  /// 关联的 [FocusNode]，用于在 [buildTextSpan] 时直接读取当前焦点状态
  /// 和选区位置，无需通过 [notifyListeners] 触发额外重绘。
  FocusNode? focusNode;

  LivePreviewController({
    super.text,
    this.focusNode,
    this.headingColor = const Color(0xFFE6EDF3),
    this.textColor = const Color(0xFFE6EDF3),
    this.boldColor = const Color(0xFFE6EDF3),
    this.italicColor = const Color(0xFFE6EDF3),
    this.codeColor = const Color(0xFF98C379),
    this.linkColor = const Color(0xFF56B6C2),
    this.strikeColor = const Color(0xFFE6EDF3),
    this.syntaxColor = const Color(0x66E6EDF3),
    this.codeBg = const Color(0x1A98C379),
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    if (source.isEmpty) {
      return TextSpan(style: style, text: '');
    }
    final baseStyle = style ?? const TextStyle();

    // 光标字符偏移量，用于决定每个 inline span 是否显示语法标记。
    final hasFocus = focusNode?.hasFocus ?? false;
    final cursorOffset = hasFocus
        ? selection.baseOffset.clamp(0, source.length)
        : -1; // -1 表示失焦，所有标记隐藏

    final spans = <InlineSpan>[];
    final lines = source.split('\n');
    var inCodeBlock = false;
    // trackLineOffset 追踪当前行在 source 中的起始字符偏移。
    var lineOffset = 0;
    for (var i = 0; i < lines.length; i++) {
      // 块级标记（标题 #、列表 -、引用 > 等）：光标在该行内就显示淡色。
      final lineReveal = cursorOffset >= 0 &&
          cursorOffset >= lineOffset &&
          cursorOffset <= lineOffset + lines[i].length;
      _renderLine(lines[i], baseStyle, spans,
          revealSyntax: lineReveal,
          inCodeBlock: inCodeBlock,
          cursorOffset: cursorOffset,
          lineOffset: lineOffset);
      // 检测围栏代码块的开启/关闭（``` 或 ~~~）。
      final trimmed = lines[i].trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inCodeBlock = !inCodeBlock;
      }
      if (i != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
        lineOffset += lines[i].length + 1; // +1 for '\n'
      }
    }
    int total = 0;
    for (final s in spans) {
      if (s is TextSpan) total += s.text?.length ?? 0;
    }
    if (total != source.length) {
      return TextSpan(style: baseStyle, text: source);
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  // --- 行级渲染 ---

  static final RegExp _headingRe = RegExp(r'^(#{1,6})(\s+)(.*)$');
  static final RegExp _quoteRe = RegExp(r'^(\s*>\s?)(.*)$');
  static final RegExp _ulRe = RegExp(r'^(\s*)([-*+])(\s+)(.*)$');
  static final RegExp _olRe = RegExp(r'^(\s*)(\d+\.)(\s+)(.*)$');
  static final RegExp _hrRe = RegExp(r'^(\s*(?:-{3,}|\*{3,}|_{3,})\s*)$');

  void _renderLine(
    String line,
    TextStyle base,
    List<InlineSpan> out, {
    required bool revealSyntax,
    bool inCodeBlock = false,
    int cursorOffset = -1,
    int lineOffset = 0,
  }) {
    if (line.isEmpty) return;

    // --- 围栏代码块内部行 ---
    //
    // 当 inCodeBlock=true 时，整行以等宽字体渲染，不解析任何行内 markdown。
    // 围栏标记本身（``` / ~~~）在 buildTextSpan 的 inCodeBlock 翻转逻辑中
    // 已被包含，这里一并处理。
    if (inCodeBlock) {
      // 代码块内，但当前行本身是闭合围栏（``` 或 ~~~）——渲染为淡化标记。
      final closingFence = RegExp(r'^\s*(`{3,}|~{3,})\s*$');
      if (closingFence.hasMatch(line)) {
        out.add(TextSpan(
          text: line,
          style: _syntaxStyle(revealSyntax),
        ));
        return;
      }
      out.add(TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: codeColor,
          backgroundColor: codeBg,
        ),
      ));
      return;
    }

    // 围栏代码块起始行（``` 或 ~~~）——语言标识保留为可见文本，
    // 符号本身淡化。
    final fenceRe = RegExp(r'^(`{3,}|~{3,})(\w*)');
    final fenceMatch = fenceRe.firstMatch(line);
    if (fenceMatch != null) {
      final marker = fenceMatch.group(1)!;
      final lang = fenceMatch.group(2)!;
      out.add(TextSpan(
        text: marker,
        style: _syntaxStyle(revealSyntax),
      ));
      if (lang.isNotEmpty) {
        out.add(TextSpan(
          text: lang,
          style: TextStyle(
            fontFamily: 'monospace',
            color: codeColor,
            fontSize: 13,
          ),
        ));
      }
      return;
    }

    // 1. 标题 ## H2
    final h = _headingRe.firstMatch(line);
    if (h != null) {
      final hashes = h.group(1)!;
      final spaces = h.group(2)!;
      final content = h.group(3)!;
      final level = hashes.length;
      final headingStyle = _headingStyleFor(level);
      // `# ` 在活跃行显示为淡色；非活跃行隐藏（保留字符占位）。
      out.add(TextSpan(
        text: hashes + spaces,
        style: _syntaxStyle(revealSyntax),
      ));
      // 标题内容的 inline 起始偏移 = lineOffset + hashes.length + spaces.length
      final contentLineOffset = lineOffset + hashes.length + spaces.length;
      _renderInline(content, headingStyle, out,
          cursorOffset: cursorOffset, lineOffset: contentLineOffset);
      return;
    }

    // 2. 引用 > xxx（注意：任务列表 - [ ] / - [x] 走下方 _ulRe 分支）
    final q = _quoteRe.firstMatch(line);
    if (q != null) {
      final marker = q.group(1)!;
      final content = q.group(2)!;
      out.add(TextSpan(text: marker, style: _syntaxStyle(revealSyntax)));
      final contentLineOffset = lineOffset + marker.length;
      _renderInline(
        content,
        TextStyle(fontStyle: FontStyle.italic, color: textColor, fontSize: 14),
        out,
        cursorOffset: cursorOffset,
        lineOffset: contentLineOffset,
      );
      return;
    }

    // 4. 分割线 --- / *** / ___
    //
    // 思源风格：用 CSS ::after 伪元素绘制 1px 灰色水平线。
    // 在 Flutter TextSpan 中，用全宽横线字符填充整行，视觉上形成 1px 细线。
    // 活跃行显示为淡色符号方便编辑；非活跃行绘制为灰色细横线。
    if (_hrRe.hasMatch(line)) {
      if (revealSyntax) {
        out.add(TextSpan(
          text: line,
          style: TextStyle(color: syntaxColor, fontSize: 14),
        ));
      } else {
        // 思源风格：一条完整横跨的灰色水平细线
        // ───────── 用 2014 个 Characters 渲染成视觉上的 1px 分割线
        final hrChar = '\u2500'; // ─ BOX DRAWINGS LIGHT HORIZONTAL
        final hrText = hrChar * line.length;
        out.add(TextSpan(
          text: hrText,
          style: TextStyle(
            color: const Color(0xFF3A3A3E), // 思源风格：深灰色水平线
            fontSize: 10,
            height: 0.4,
          ),
        ));
      }
      return;
    }

    // 5. 无序列表 `- item` 和任务列表 `- [ ] item` / `- [x] item`
    //
    // 核心约束：不能增减字符数量（长度不变量），不能用 WidgetSpan
    // （EditableText 渲染不可靠）。所有视觉效果通过 TextStyle 实现。
    //
    // 任务列表：思源风格 SVG 图标（已勾选 ✓ 绿色 / 未勾选 □ 灰色边框）。
    //   已勾选：`[` ]` 渲染为绿色粗边框 + 绿色 ✓ 勾号，内容带删除线。
    //   未勾选：`[` ]` 渲染为灰色粗边框，中间空格透明，正常内容。
    // 普通无序列表根据缩进层级渲染不同 bullet 样式：
    //   首层：实心圆点 ● (U+25CF)  思源风格
    //   二层：空心圆点 ○ (U+25CB)
    //   三层：实心方块 ■ (U+25A0)
    final ul = _ulRe.firstMatch(line);
    if (ul != null) {
      final indent = ul.group(1)!;
      final bullet = ul.group(2)!;
      final spaces = ul.group(3)!;
      final content = ul.group(4)!;

      // 根据缩进推断嵌套层级
      final indentLevel = indent.length ~/ 2;

      // 注意：`\s*(.*)$` 而非 `\s+(.*)$`——允许 `[ ]` 后没有内容也识别为任务列表。
      final taskRe = RegExp(r'^\[( |x|X)\](\s*)(.*)$');
      final taskMatch = taskRe.firstMatch(content);

      out.add(TextSpan(text: indent, style: const TextStyle(fontSize: 14)));

      if (taskMatch != null) {
        // --- 任务列表项（思源风格）---
        // 使用 Unicode BALLOT BOX 字符族：☐ (U+2610) 未勾选 / ☑ (U+2611) 已勾选
        // 这两个字符是同族的等宽方框，切换勾选状态时大小保持不变。
        final checked = taskMatch.group(1)!.toLowerCase() == 'x';
        final taskContent = taskMatch.group(3)!;
        final trailingSpaces = taskMatch.group(2)!;

        final checkColor = checked
            ? const Color(0xFF4CAF50) // 已勾选：绿色勾号
            : const Color(0xFF6E6E73); // 未勾选：灰色边框

        // `-` → 不渲染，仅占位
        out.add(TextSpan(
          text: bullet,
          style: const TextStyle(color: Color(0x00000000), fontSize: 14),
        ));
        // ` ` (bullet 后的空格)
        out.add(TextSpan(text: ' ', style: const TextStyle(fontSize: 14)));

        // ☐ 或 ☑（1 个字符替换 [x] / [ ] 的 3 个字符效果）
        final boxChar = checked ? '\u2611' : '\u2610'; // ☑ 或 ☐
        out.add(TextSpan(
          text: boxChar,
          style: TextStyle(
            color: checkColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ));
        // 补 2 个透明空格保持长度不变量（源码 `[x]` / `[ ]` 是 3 个字符）
        out.add(TextSpan(
          text: '  ',
          style: const TextStyle(color: Color(0x00000000), fontSize: 14),
        ));
        // `]` 之后的空格（保持源码长度不变）
        out.add(TextSpan(text: trailingSpaces, style: const TextStyle(fontSize: 14)));
        // 内容
        final contentLineOffset = lineOffset + indent.length + bullet.length + 1 + 3 + trailingSpaces.length;
        _renderInline(
          taskContent,
          checked
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: const Color(0xFF86868B),
                  fontSize: 14,
                )
              : TextStyle(color: textColor, fontSize: 14),
          out,
          cursorOffset: cursorOffset,
          lineOffset: contentLineOffset,
        );
      } else {
        // --- 普通无序列表项 ---
        // 根据缩进层级选择 bullet 样式
        String bulletText;
        TextStyle bulletStyle;
        switch (indentLevel) {
          case 1: // 二层：空心圆点
            bulletText = '\u25CB'; // ○
            bulletStyle = TextStyle(
              color: linkColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            );
          case 2: // 三层及以上：实心方块
            bulletText = '\u25A0'; // ■
            bulletStyle = TextStyle(
              color: linkColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            );
          default: // 首层：实心圆点
            bulletText = '\u25CF'; // ●
            bulletStyle = TextStyle(
              color: linkColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            );
        }
        out.add(TextSpan(text: bulletText, style: bulletStyle));
        // bullet 之后的空格
        out.add(TextSpan(text: spaces, style: const TextStyle(fontSize: 14)));
        final contentLineOffset =
            lineOffset + indent.length + bullet.length + spaces.length;
        _renderInline(content, TextStyle(color: textColor, fontSize: 14), out,
            cursorOffset: cursorOffset, lineOffset: contentLineOffset);
      }
      return;
    }

    // 6. 有序列表
    final ol = _olRe.firstMatch(line);
    if (ol != null) {
      final indent = ol.group(1)!;
      final num = ol.group(2)!;
      final spaces = ol.group(3)!;
      final content = ol.group(4)!;
      out.add(TextSpan(text: indent, style: const TextStyle(fontSize: 14)));
      out.add(TextSpan(text: num, style: TextStyle(color: linkColor, fontWeight: FontWeight.w700, fontSize: 14)));
      out.add(TextSpan(text: spaces, style: const TextStyle(fontSize: 14)));
      final contentLineOffset = lineOffset + indent.length + num.length + spaces.length;
      _renderInline(content, TextStyle(color: textColor, fontSize: 14), out,
          cursorOffset: cursorOffset, lineOffset: contentLineOffset);
      return;
    }

    // 7. 普通段落
    _renderInline(line, TextStyle(color: textColor, fontSize: 14), out,
        cursorOffset: cursorOffset, lineOffset: lineOffset);
  }

  TextStyle _headingStyleFor(int level) {
    final size = switch (level) {
      1 => 26.0,
      2 => 22.0,
      3 => 19.0,
      4 => 17.0,
      5 => 15.0,
      _ => 14.0,
    };
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: headingColor,
      height: 1.3,
    );
  }

  /// 返回应用到 markdown 语法符号上的样式。
  ///
  /// 活跃行（光标所在行）使用 [syntaxColor] 渲染——可见但淡。
  /// 非活跃行将 fontSize 缩小到 1e-3 并设全透明色，让符号在视觉上完全消失，
  /// 但字符仍然占位（不破坏选区/光标定位的字符索引）。
  /// 返回应用到 markdown 语法符号上的样式。
  ///
  /// 活跃行（光标所在行）使用 [syntaxColor] 渲染——可见但淡。
  /// 非活跃行将颜色设为全透明，让符号在视觉上完全消失。
  /// 不依赖 [base] 的 fontSize/color（EditableText 传入的 base 可能不含这些），
  /// 而是用硬编码的默认值，确保样式始终生效。
  TextStyle _syntaxStyle(bool reveal) {
    if (reveal) {
      return TextStyle(color: syntaxColor, fontWeight: FontWeight.w400, fontSize: 14);
    }
    return const TextStyle(
      color: Color(0x00000000),
      fontSize: 14,
    );
  }

  // --- 行内渲染 ---
  //
  // 解析 inline markdown：image、link、code、bold、italic、strike。
  // 每个匹配命中后，将语法符号包成 syntaxColor，把文字本体使用相应的视觉
  // 样式（粗体/斜体/等宽/下划线/删除线）渲染。

  /// 行内模式优先级（先匹配先赢）。
  ///
  /// image > link：image 是 `![..](..)`，link 是 `[..](..)`，image 是 link
  /// 的严格超集，必须先尝试 image。
  /// bold > italic：`**x**` 否则会被 italic 重复匹配一次。
  static final List<_InlineKind> _inlinePriority = [
    _InlineKind.image,
    _InlineKind.link,
    _InlineKind.code,
    _InlineKind.boldItalic, // 必须在 bold 和 italic 之前匹配
    _InlineKind.bold,
    _InlineKind.italic,
    _InlineKind.strike,
  ];

  static final Map<_InlineKind, RegExp> _patterns = {
    _InlineKind.image: RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
    _InlineKind.link: RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    _InlineKind.code: RegExp(r'`([^`\n]+)`'),
    _InlineKind.boldItalic: RegExp(r'\*\*\*([^*\n]+)\*\*\*'),
    _InlineKind.bold: RegExp(r'\*\*([^*\n]+)\*\*'),
    _InlineKind.italic: RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
    _InlineKind.strike: RegExp(r'~~([^~\n]+)~~'),
  };

  void _renderInline(
    String text,
    TextStyle base,
    List<InlineSpan> out, {
    int cursorOffset = -1,
    int lineOffset = 0,
  }) {
    if (text.isEmpty) return;

    final candidates = <_InlineMatch>[];
    for (final kind in _inlinePriority) {
      final regex = _patterns[kind]!;
      for (final m in regex.allMatches(text)) {
        candidates.add(_InlineMatch(kind, m.start, m.end, m));
      }
    }
    candidates.sort((a, b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      return _inlinePriority.indexOf(a.kind).compareTo(_inlinePriority.indexOf(b.kind));
    });

    final picked = <_InlineMatch>[];
    var taken = 0;
    for (final c in candidates) {
      if (c.start < taken) continue;
      picked.add(c);
      taken = c.end;
    }

    var cursor = 0;
    for (final p in picked) {
      if (p.start > cursor) {
        out.add(TextSpan(text: text.substring(cursor, p.start), style: base));
      }
      // 计算光标是否在这个 inline span 的绝对范围内。
      final absStart = lineOffset + p.start;
      final absEnd = lineOffset + p.end;
      final spanReveal = cursorOffset >= 0 &&
          cursorOffset >= absStart &&
          cursorOffset < absEnd;
      _emitInlineSpan(p, base, out, revealSyntax: spanReveal);
      cursor = p.end;
    }
    if (cursor < text.length) {
      out.add(TextSpan(text: text.substring(cursor), style: base));
    }
  }


  void _emitInlineSpan(
    _InlineMatch m,
    TextStyle base,
    List<InlineSpan> out, {
    required bool revealSyntax,
  }) {
    final match = m.match;
    final sy = _syntaxStyle(revealSyntax);
    switch (m.kind) {
      case _InlineKind.image:
        // 图片占位：用透明文本保持长度不变量
        final rawMatch = match.group(0)!;
        out.add(TextSpan(
          text: rawMatch,
          style: const TextStyle(color: Color(0x00000000)),
        ));
      case _InlineKind.link:
        final txt = match.group(1) ?? '';
        final url = match.group(2) ?? '';
        out.add(TextSpan(text: '[', style: sy));
        out.add(TextSpan(
            text: txt,
            style: TextStyle(color: linkColor, decoration: TextDecoration.underline, fontSize: 14)));
        out.add(TextSpan(text: '](', style: sy));
        out.add(TextSpan(text: url, style: sy));
        out.add(TextSpan(text: ')', style: sy));
      case _InlineKind.code:
        final body = match.group(1) ?? '';
        out.add(TextSpan(text: '`', style: sy));
        out.add(TextSpan(
            text: body,
            style: TextStyle(
              fontFamily: 'monospace',
              color: codeColor,
              backgroundColor: codeBg,
              fontSize: 13,
            )));
        out.add(TextSpan(text: '`', style: sy));
      case _InlineKind.boldItalic:
        final body = match.group(1) ?? '';
        out.add(TextSpan(text: '***', style: sy));
        out.add(TextSpan(
            text: body,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: boldColor,
                fontSize: 14)));
        out.add(TextSpan(text: '***', style: sy));
      case _InlineKind.bold:
        final body = match.group(1) ?? '';
        out.add(TextSpan(text: '**', style: sy));
        out.add(TextSpan(
            text: body,
            style: TextStyle(fontWeight: FontWeight.w800, color: boldColor, fontSize: 14)));
        out.add(TextSpan(text: '**', style: sy));
      case _InlineKind.italic:
        final body = match.group(1) ?? '';
        out.add(TextSpan(text: '*', style: sy));
        out.add(TextSpan(
            text: body,
            style: TextStyle(fontStyle: FontStyle.italic, color: italicColor, fontSize: 14)));
        out.add(TextSpan(text: '*', style: sy));
      case _InlineKind.strike:
        final body = match.group(1) ?? '';
        out.add(TextSpan(text: '~~', style: sy));
        out.add(TextSpan(
            text: body,
            style: TextStyle(
                decoration: TextDecoration.lineThrough, color: strikeColor, fontSize: 14)));
        out.add(TextSpan(text: '~~', style: sy));
    }
  }
}

enum _InlineKind { image, link, code, boldItalic, bold, italic, strike }

class _InlineMatch {
  final _InlineKind kind;
  final int start;
  final int end;
  final RegExpMatch match;
  const _InlineMatch(this.kind, this.start, this.end, this.match);
}
