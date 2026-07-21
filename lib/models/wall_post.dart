class WallReactions {
  final Map<String, int> summary;
  final String? myEmoji;

  WallReactions({required this.summary, this.myEmoji});

  factory WallReactions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WallReactions(summary: {});
    final rawSummary = json['summary'] as Map<String, dynamic>? ?? {};
    return WallReactions(
      summary: rawSummary.map((k, v) => MapEntry(k, (v as num).toInt())),
      myEmoji: json['my_emoji'] as String?,
    );
  }

  int get total => summary.values.fold(0, (a, b) => a + b);
}

class WallMedia {
  final int wallMediaId;
  final String mediaType;
  final String fileSrc;
  final String fileName;

  WallMedia({
    required this.wallMediaId,
    required this.mediaType,
    required this.fileSrc,
    required this.fileName,
  });

  factory WallMedia.fromJson(Map<String, dynamic> json) {
    return WallMedia(
      wallMediaId: json['wallMediaId'] ?? 0,
      mediaType: json['mediaType'] ?? '',
      fileSrc: json['fileSrc'] ?? '',
      fileName: json['fileName'] ?? '',
    );
  }

  bool get isImage => mediaType == 'image';
  bool get isVideoUrl => mediaType == 'video_url';
}

class WallPost {
  final int wallPostId;
  final int userId;
  final String content;
  final String age;
  final String createdAt;
  final String authorName;
  final String authorPhoto;
  final String? authorRole;
  final int commentCount;
  final int reactionCount;
  final WallReactions reactions;
  final List<WallMedia> media;
  final bool isMine;

  WallPost({
    required this.wallPostId,
    required this.userId,
    required this.content,
    required this.age,
    required this.createdAt,
    required this.authorName,
    required this.authorPhoto,
    this.authorRole,
    required this.commentCount,
    required this.reactionCount,
    required this.reactions,
    required this.media,
    required this.isMine,
  });

  factory WallPost.fromJson(Map<String, dynamic> json) {
    return WallPost(
      wallPostId: json['wallPostId'] ?? 0,
      userId: json['userId'] ?? 0,
      content: json['content'] ?? '',
      age: json['age'] ?? '',
      createdAt: json['createdAt'] ?? '',
      authorName: json['authorName'] ?? '',
      authorPhoto: json['authorPhoto'] ?? '',
      authorRole: json['authorRole'],
      commentCount: json['commentCount'] ?? 0,
      reactionCount: json['reactionCount'] ?? 0,
      reactions: WallReactions.fromJson(json['reactions']),
      media: (json['media'] as List<dynamic>? ?? [])
          .map((m) => WallMedia.fromJson(m as Map<String, dynamic>))
          .toList(),
      isMine: json['isMine'] ?? false,
    );
  }
}

class WallComment {
  final int wallCommentId;
  final int? parentCommentId;
  final int userId;
  final String content;
  final String age;
  final String authorName;
  final String authorPhoto;
  final String? authorRole;
  final int reactionCount;
  final WallReactions reactions;
  final bool isMine;

  WallComment({
    required this.wallCommentId,
    this.parentCommentId,
    required this.userId,
    required this.content,
    required this.age,
    required this.authorName,
    required this.authorPhoto,
    this.authorRole,
    required this.reactionCount,
    required this.reactions,
    required this.isMine,
  });

  factory WallComment.fromJson(Map<String, dynamic> json) {
    return WallComment(
      wallCommentId: json['wallCommentId'] ?? 0,
      parentCommentId: json['parentCommentId'],
      userId: json['userId'] ?? 0,
      content: json['content'] ?? '',
      age: json['age'] ?? '',
      authorName: json['authorName'] ?? '',
      authorPhoto: json['authorPhoto'] ?? '',
      authorRole: json['authorRole'],
      reactionCount: json['reactionCount'] ?? 0,
      reactions: WallReactions.fromJson(json['reactions']),
      isMine: json['isMine'] ?? false,
    );
  }
}
