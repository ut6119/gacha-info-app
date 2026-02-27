class XPost {
  const XPost({
    required this.id,
    required this.platform,
    required this.username,
    required this.content,
    required this.url,
    required this.postedAt,
    this.matchedKeyword,
  });

  final String id;
  final String platform;
  final String username;
  final String content;
  final String url;
  final DateTime postedAt;
  final String? matchedKeyword;

  factory XPost.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['postedAt'] ?? '').toString();
    final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now().toUtc();

    return XPost(
      id: (json['id'] ?? '').toString(),
      platform: (json['platform'] ?? 'X').toString(),
      username: (json['username'] ?? '@unknown').toString(),
      content: (json['content'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      postedAt: parsedDate,
      matchedKeyword: json['matchedKeyword']?.toString(),
    );
  }
}
