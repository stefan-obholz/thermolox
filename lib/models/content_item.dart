/// A page or blog article from the Supabase `content` table.
class ContentItem {
  final String id;
  final String type; // 'page' or 'article'
  final String title;
  final String handle;
  final String? body;
  final String? summary;
  final String? imageUrl;
  final String? imageAlt;
  final List<String> tags;
  final String? blogTitle;
  final String? blogHandle;
  final DateTime? publishedAt;
  final bool isVisible;

  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.handle,
    this.body,
    this.summary,
    this.imageUrl,
    this.imageAlt,
    this.tags = const [],
    this.blogTitle,
    this.blogHandle,
    this.publishedAt,
    this.isVisible = true,
  });

  factory ContentItem.fromSupabase(Map<String, dynamic> row) {
    return ContentItem(
      id: row['id'] as String,
      type: row['type'] as String,
      title: row['title'] as String,
      handle: row['handle'] as String,
      body: row['body'] as String?,
      summary: row['summary'] as String?,
      imageUrl: row['image_url'] as String?,
      imageAlt: row['image_alt'] as String?,
      tags: (row['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          const [],
      blogTitle: row['blog_title'] as String?,
      blogHandle: row['blog_handle'] as String?,
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'] as String)
          : null,
      isVisible: row['is_visible'] as bool? ?? true,
    );
  }

  bool get isPage => type == 'page';
  bool get isArticle => type == 'article';
}
