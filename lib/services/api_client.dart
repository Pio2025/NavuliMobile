import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/wall_post.dart';
import 'auth_service.dart';

class WallFeedResult {
  final List<WallPost> posts;
  final bool hasMore;
  final List<Map<String, dynamic>> schools;
  final int activeSchoolId;

  WallFeedResult({
    required this.posts,
    required this.hasMore,
    this.schools = const [],
    this.activeSchoolId = 0,
  });
}

typedef SchoolScopedList = ({
  List<Map<String, dynamic>> items,
  List<Map<String, dynamic>> schools,
  int activeSchoolId,
});

class ApiClient {
  final AuthService auth;

  ApiClient(this.auth);

  Future<SchoolScopedList> getNotices({int? schoolId}) async {
    final uri = Uri.parse(ApiConfig.noticesUrl).replace(
      queryParameters: schoolId != null ? {'sch_id': '$schoolId'} : null,
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load notices.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['notices'] ?? []),
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      activeSchoolId: (body['activeSchoolId'] as num? ?? 0).toInt(),
    );
  }

  Future<SchoolScopedList> getAnnouncements({int? schoolId}) async {
    final uri = Uri.parse(ApiConfig.announcementsUrl).replace(
      queryParameters: schoolId != null ? {'sch_id': '$schoolId'} : null,
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load announcements.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['announcements'] ?? []),
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      activeSchoolId: (body['activeSchoolId'] as num? ?? 0).toInt(),
    );
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await http
        .get(Uri.parse(ApiConfig.dashboardUrl), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load dashboard.');
    }
    return body;
  }

  Future<WallFeedResult> getWallFeed({int offset = 0, int? schoolId}) async {
    final uri = Uri.parse(ApiConfig.wallFeedUrl).replace(
      queryParameters: {
        'offset': '$offset',
        if (schoolId != null) 'sch_id': '$schoolId',
      },
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load the wall feed.');
    }
    return WallFeedResult(
      posts: (body['posts'] as List<dynamic>? ?? [])
          .map((p) => WallPost.fromJson(p as Map<String, dynamic>))
          .toList(),
      hasMore: body['hasMore'] ?? false,
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      activeSchoolId: (body['activeSchoolId'] as num? ?? 0).toInt(),
    );
  }

  Future<WallPost> createWallPost({
    required String content,
    List<http.MultipartFile>? mediaFiles,
    List<String>? videoUrls,
    int? schoolId,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.wallPostUrl))
      ..headers.addAll(auth.authHeaders)
      ..fields['content'] = content;

    if (schoolId != null) {
      request.fields['sch_id'] = '$schoolId';
    }

    for (final url in videoUrls ?? const <String>[]) {
      request.fields['video_urls[]'] = url;
    }
    if (mediaFiles != null) {
      request.files.addAll(mediaFiles);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create the post.');
    }
    return WallPost.fromJson(body['post'] as Map<String, dynamic>);
  }

  Future<List<WallComment>> getComments(int postId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.wallCommentsUrl(postId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load comments.');
    }
    return (body['comments'] as List<dynamic>? ?? [])
        .map((c) => WallComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<WallComment> addComment(int postId, String content, {int? parentCommentId}) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.wallCommentUrl(postId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': content,
            'parent_comment_id': ?parentCommentId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add comment.');
    }
    return WallComment.fromJson(body['comment'] as Map<String, dynamic>);
  }

  Future<WallReactions> react({
    required String targetType,
    required int targetId,
    required String emoji,
  }) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.wallReactUrl),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'target_type': targetType,
            'target_id': targetId,
            'emoji': emoji,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to react.');
    }
    return WallReactions.fromJson(body);
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final res = await http
        .get(Uri.parse(ApiConfig.notificationsUrl), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load notifications.');
    }
    return body;
  }

  Future<void> markNotificationsRead() async {
    final res = await http
        .post(Uri.parse(ApiConfig.notificationsMarkReadUrl), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to mark notifications read.');
    }
  }
}
