import 'package:url_launcher/url_launcher.dart';

class LinkInfo {
  final String text;
  final String url;
  final int startOffset;
  final int endOffset;

  const LinkInfo({
    required this.text,
    required this.url,
    required this.startOffset,
    required this.endOffset,
  });
}

class LinkHandler {
  static List<LinkInfo> extractLinks(String text) {
    final links = <LinkInfo>[];
    final re = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final m in re.allMatches(text)) {
      links.add(LinkInfo(
        text: m.group(1)!,
        url: m.group(2)!,
        startOffset: m.start,
        endOffset: m.end,
      ));
    }
    return links;
  }

  static LinkInfo? isLinkAtOffset(List<LinkInfo> links, int offset) {
    for (final link in links) {
      if (offset >= link.startOffset && offset < link.endOffset) {
        return link;
      }
    }
    return null;
  }

  static Future<void> openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
