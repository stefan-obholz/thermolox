import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../models/content_item.dart';
import '../widgets/html_content_view.dart';

class ContentDetailPage extends StatelessWidget {
  final ContentItem item;

  const ContentDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.isArticle ? 'Blog' : item.title,
          style: const TextStyle(fontFamily: 'Times New Roman', fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (item.isArticle && item.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  children: item.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.peachDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Text(
              item.title,
              style: const TextStyle(fontFamily: 'Times New Roman', 
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                height: 1.2,
              ),
            ),
            if (item.publishedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '${item.publishedAt!.day}.${item.publishedAt!.month}.${item.publishedAt!.year}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (item.body != null && item.body!.isNotEmpty)
              HtmlContentView(html: item.body!),
          ],
        ),
      ),
    );
  }
}
