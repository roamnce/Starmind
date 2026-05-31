// lib/src/mindmap/domain/note_content.dart

/// 富文本内容（GuruMind JSON segments 格式）。
///
/// 设计依据：
/// - GuruMind: 标准化 JSON segments
/// - 支持：文本样式、图片摘录、填空标记
class NoteContent {
  final List<Segment> segments;

  const NoteContent({required this.segments});

  /// 从 JSON 解析
  factory NoteContent.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List;
    return NoteContent(
      segments: segmentsList
          .map((s) => Segment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  /// 纯文本内容（去除样式）
  String get plainText {
    return segments
        .where((s) => s.type == SegmentType.text)
        .map((s) => s.text ?? '')
        .join('');
  }
}

/// 段落类型
enum SegmentType {
  text,
  image,
}

/// 段落基类
class Segment {
  final SegmentType type;

  // 文本段落字段
  final String? text;
  final TextStyle? style;

  // 图片段落字段
  final String? path; // assets/xxx.png
  final double? width;
  final double? height;
  final int? fit;

  const Segment({
    required this.type,
    this.text,
    this.style,
    this.path,
    this.width,
    this.height,
    this.fit,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    return Segment(
      type: typeStr == 'text' ? SegmentType.text : SegmentType.image,
      text: json['text'] as String?,
      style: json['style'] != null
          ? TextStyle.fromJson(json['style'] as Map<String, dynamic>)
          : null,
      path: json['path'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      fit: json['fit'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type == SegmentType.text ? 'text' : 'image'};
    if (text != null) json['text'] = text;
    if (style != null) json['style'] = style!.toJson();
    if (path != null) json['path'] = path;
    if (width != null) json['width'] = width;
    if (height != null) json['height'] = height;
    if (fit != null) json['fit'] = fit;
    return json;
  }
}

/// 文本样式（GuruMind 完整样式）
class TextStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool cloze; // 填空标记
  final String? link;
  final String? textColor;
  final String? backgroundColor;
  final double? fontSize;
  final String? textAlign;

  const TextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.cloze = false,
    this.link,
    this.textColor,
    this.backgroundColor,
    this.fontSize,
    this.textAlign,
  });

  factory TextStyle.fromJson(Map<String, dynamic> json) {
    return TextStyle(
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strikethrough: json['strikethrough'] as bool? ?? false,
      cloze: json['cloze'] as bool? ?? false,
      link: json['link'] as String?,
      textColor: json['textColor'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      textAlign: json['textAlign'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strikethrough': strikethrough,
        'cloze': cloze,
        if (link != null) 'link': link,
        if (textColor != null) 'textColor': textColor,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (fontSize != null) 'fontSize': fontSize,
        if (textAlign != null) 'textAlign': textAlign,
      };
}