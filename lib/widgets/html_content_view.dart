import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Renders simple HTML content (h1-h3, p, ul/li, strong, em, a, img)
/// as native Flutter widgets with CLIMALOX styling.
/// No external dependencies needed.
class HtmlContentView extends StatelessWidget {
  final String html;
  final TextStyle? baseStyle;

  const HtmlContentView({super.key, required this.html, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = baseStyle ??
        theme.textTheme.bodyLarge?.copyWith(height: 1.7) ??
        const TextStyle(fontSize: 16, height: 1.7);

    final widgets = _parseHtml(html, style, theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _parseHtml(String html, TextStyle style, ThemeData theme) {
    final widgets = <Widget>[];
    final cleaned = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—');

    // Split into blocks by major tags
    final blockRegex = RegExp(
      r'<(h[1-3]|p|ul|ol|li|img|hr)[^>]*>(.*?)</\1>|<(img|hr)[^>]*/>',
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in blockRegex.allMatches(cleaned)) {
      // Text between blocks
      if (match.start > lastEnd) {
        final between = _stripTags(cleaned.substring(lastEnd, match.start)).trim();
        if (between.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRichText(between, style),
          ));
        }
      }

      final tag = match.group(1) ?? match.group(3) ?? '';
      final content = match.group(2) ?? '';

      switch (tag) {
        case 'h1':
          widgets.add(Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: _buildRichText(
              _stripTags(content),
              style.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Times New Roman',
                height: 1.3,
              ),
            ),
          ));
          break;
        case 'h2':
          widgets.add(Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: _buildRichText(
              _stripTags(content),
              style.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ));
          break;
        case 'h3':
          widgets.add(Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: _buildRichText(
              _stripTags(content),
              style.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ));
          break;
        case 'p':
          final text = _stripTags(content).trim();
          if (text.isNotEmpty) {
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRichText(text, style),
            ));
          }
          break;
        case 'ul':
        case 'ol':
          final items = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true)
              .allMatches(content)
              .map((m) => _stripTags(m.group(1) ?? '').trim())
              .where((s) => s.isNotEmpty)
              .toList();
          for (int i = 0; i < items.length; i++) {
            final bullet = tag == 'ol' ? '${i + 1}.' : '•';
            widgets.add(Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(bullet, style: style.copyWith(
                      color: AppTheme.peachDark,
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                  Expanded(child: _buildRichText(items[i], style)),
                ],
              ),
            ));
          }
          widgets.add(const SizedBox(height: 8));
          break;
        case 'hr':
          widgets.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ));
          break;
      }
      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < cleaned.length) {
      final remaining = _stripTags(cleaned.substring(lastEnd)).trim();
      if (remaining.isNotEmpty) {
        widgets.add(_buildRichText(remaining, style));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(_buildRichText(_stripTags(cleaned), style));
    }

    return widgets;
  }

  Widget _buildRichText(String text, TextStyle style) {
    return Text(text, style: style);
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
