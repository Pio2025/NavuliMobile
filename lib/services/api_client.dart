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
  bool hasMore,
  Map<String, dynamic> permissions,
});

typedef ClassroomScopedList = ({
  List<Map<String, dynamic>> items,
  int total,
  bool hasMore,
  List<Map<String, dynamic>> schools,
  Map<String, dynamic> permissions,
});

class ApiClient {
  final AuthService auth;

  ApiClient(this.auth);

  Future<SchoolScopedList> getNotices({int? schoolId, int offset = 0}) async {
    final uri = Uri.parse(ApiConfig.noticesUrl).replace(
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
      throw Exception(body['message'] ?? 'Failed to load notices.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['notices'] ?? []),
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      activeSchoolId: (body['activeSchoolId'] as num? ?? 0).toInt(),
      hasMore: body['hasMore'] == true,
      permissions: Map<String, dynamic>.from(body['permissions'] ?? {}),
    );
  }

  Future<SchoolScopedList> getAnnouncements({int? schoolId, int offset = 0}) async {
    final uri = Uri.parse(ApiConfig.announcementsUrl).replace(
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
      throw Exception(body['message'] ?? 'Failed to load announcements.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['announcements'] ?? []),
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      activeSchoolId: (body['activeSchoolId'] as num? ?? 0).toInt(),
      hasMore: body['hasMore'] == true,
      permissions: Map<String, dynamic>.from(body['permissions'] ?? {}),
    );
  }

  Future<Map<String, dynamic>> createNotice({
    required String title,
    required String content,
    String priority = 'Normal',
    String audience = 'All',
    bool isPinned = false,
    int? schoolId,
  }) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.noticesUrl),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'content': content,
            'priority': priority,
            'audience': audience,
            'is_pinned': isPinned,
            if (schoolId != null) 'sch_id': schoolId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to post notice.');
    }
    return Map<String, dynamic>.from(body['notice']);
  }

  Future<Map<String, dynamic>> updateNotice(
    int id, {
    required String title,
    required String content,
    String priority = 'Normal',
    String audience = 'All',
    bool isPinned = false,
  }) async {
    final res = await http
        .put(
          Uri.parse(ApiConfig.noticeUrl(id)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'content': content,
            'priority': priority,
            'audience': audience,
            'is_pinned': isPinned,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update notice.');
    }
    return Map<String, dynamic>.from(body['notice']);
  }

  Future<void> deleteNotice(int id) async {
    final res = await http
        .delete(Uri.parse(ApiConfig.noticeUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete notice.');
    }
  }

  Future<Map<String, dynamic>> toggleNoticePin(int id) async {
    final res = await http
        .post(Uri.parse(ApiConfig.noticePinUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update pin.');
    }
    return Map<String, dynamic>.from(body['notice']);
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    String priority = 'Info',
    int? schoolId,
  }) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.announcementsUrl),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'content': content,
            'priority': priority,
            if (schoolId != null) 'sch_id': schoolId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to post announcement.');
    }
    return Map<String, dynamic>.from(body['announcement']);
  }

  Future<Map<String, dynamic>> updateAnnouncement(
    int id, {
    required String title,
    required String content,
    String priority = 'Info',
  }) async {
    final res = await http
        .put(
          Uri.parse(ApiConfig.announcementUrl(id)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'content': content,
            'priority': priority,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update announcement.');
    }
    return Map<String, dynamic>.from(body['announcement']);
  }

  Future<void> deleteAnnouncement(int id) async {
    final res = await http
        .delete(Uri.parse(ApiConfig.announcementUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete announcement.');
    }
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

  Future<ClassroomScopedList> getClassrooms({
    String scope = 'all',
    int? childId,
    String? search,
    String? status,
    int? schId,
    int limit = 10,
    int offset = 0,
  }) async {
    final uri = Uri.parse(ApiConfig.classroomListUrl).replace(
      queryParameters: {
        'scope': scope,
        'limit': '$limit',
        'offset': '$offset',
        if (childId != null) 'childId': '$childId',
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (schId != null) 'sch_id': '$schId',
      },
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load classrooms.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['classrooms'] ?? []),
      total: (body['total'] as num? ?? 0).toInt(),
      hasMore: body['hasMore'] == true,
      schools: List<Map<String, dynamic>>.from(body['schools'] ?? []),
      permissions: Map<String, dynamic>.from(body['permissions'] ?? {}),
    );
  }

  Future<List<Map<String, dynamic>>> getClassroomStreams({int? schId}) async {
    final uri = Uri.parse(ApiConfig.classroomStreamsUrl).replace(
      queryParameters: {
        if (schId != null) 'sch_id': '$schId',
      },
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load streams.');
    }
    return List<Map<String, dynamic>>.from(body['streams'] ?? []);
  }

  Future<Map<String, dynamic>> createClassroom({
    required int streamId,
    required String className,
    required int classYear,
    String classStatus = 'Active',
    int? schId,
  }) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.classroomListUrl),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'stream_id': streamId,
            'class_name': className,
            'class_year': classYear,
            'class_status': classStatus,
            if (schId != null) 'sch_id': schId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create classroom.');
    }
    return Map<String, dynamic>.from(body['classroom']);
  }

  Future<Map<String, dynamic>> updateClassroom(
    int id, {
    required int streamId,
    required String className,
    required int classYear,
    String classStatus = 'Active',
  }) async {
    final res = await http
        .put(
          Uri.parse(ApiConfig.classroomUrl(id)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'stream_id': streamId,
            'class_name': className,
            'class_year': classYear,
            'class_status': classStatus,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update classroom.');
    }
    return Map<String, dynamic>.from(body['classroom']);
  }

  Future<void> deleteClassroom(int id) async {
    final res = await http
        .delete(Uri.parse(ApiConfig.classroomUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete classroom.');
    }
  }

  Future<Map<String, dynamic>> getClassroomDetail(int id) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load classroom.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomSubjects(int id, {int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomSubjectsUrl(id, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load subjects.');
    }
    return {
      ...Map<String, dynamic>.from(body['subjects'] ?? {}),
      'canFullAccess': body['canFullAccess'] == true,
    };
  }

  Future<Map<String, dynamic>> getClassroomStaff(int id) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomStaffUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load staff.');
    }
    return Map<String, dynamic>.from(body['staff'] ?? {});
  }

  Future<({List<Map<String, dynamic>> items, int total, bool hasMore})> getClassroomStudents(
    int id, {
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(ApiConfig.classroomStudentsUrl(id)).replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final res = await http
        .get(uri, headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load students.');
    }
    return (
      items: List<Map<String, dynamic>>.from(body['students'] ?? []),
      total: (body['total'] as num? ?? 0).toInt(),
      hasMore: body['hasMore'] == true,
    );
  }

  Future<Map<String, dynamic>> getClassroomAttendance(int id) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomAttendanceUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load attendance.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomAttendanceTerms(int id) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomAttendanceTermsUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load attendance terms.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomAttendanceDaily(int id, {int? term, int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomAttendanceDailyUrl(id, term: term, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load daily attendance.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomAttendanceSubject(int id, {int? term, int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomAttendanceSubjectUrl(id, term: term, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load subject attendance.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomExam(int id, {int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomExamUrl(id, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load exam results.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getClassroomDiscussion(int id) async {
    final res = await http
        .get(Uri.parse(ApiConfig.classroomDiscussionUrl(id)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load discussion.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectDashboard(int classSubId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectDashboardUrl(classSubId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load subject dashboard.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectLessons(int classSubId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectLessonsUrl(classSubId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load lessons.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectLessonsCalendar(int classSubId, {int? term}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectLessonsCalendarUrl(classSubId, term: term)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load lesson calendar.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectAssignments(int classSubId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectAssignmentsUrl(classSubId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load assignments.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectAssignmentDetail(int classSubId, int assignmentId, {int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectAssignmentDetailUrl(classSubId, assignmentId, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to load assignment.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getSubjectFeedback(int classSubId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.subjectFeedbackUrl(classSubId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load feedback.');
    }
    return body;
  }

  Future<Map<String, dynamic>> submitSubjectFeedback(
    int classSubId, {
    required int overallRating,
    int teachingRating = 0,
    int contentRating = 0,
    int engagementRating = 0,
    String comment = '',
    bool isAnonymous = false,
  }) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.subjectFeedbackUrl(classSubId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'overall_rating': overallRating,
            'teaching_rating': teachingRating,
            'content_rating': contentRating,
            'engagement_rating': engagementRating,
            'comment': comment,
            'is_anonymous': isAnonymous,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to submit feedback.');
    }
    return body;
  }

  Future<Map<String, dynamic>> getLessonDetail(int lessonId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonDetailUrl(lessonId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load lesson.');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> getLessonDiscussionFeed(int lessonId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonDiscussionFeedUrl(lessonId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load discussion.');
    }
    return List<Map<String, dynamic>>.from(body['discussion'] ?? []);
  }

  Future<String> getChatSocketToken() async {
    final res = await http
        .get(Uri.parse(ApiConfig.chatSocketTokenUrl), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to get socket token.');
    }
    return body['token'] as String;
  }

  Future<Map<String, dynamic>> getLessonQuizScore(int quizId, {int? childId}) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonQuizScoreUrl(quizId, childId: childId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to load quiz score.');
    }
    return body;
  }

  Future<Map<String, dynamic>> postLessonDiscussion(
    int lessonId, {
    String message = '',
    List<http.MultipartFile>? photos,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.lessonDiscussionPostUrl(lessonId)))
      ..headers.addAll(auth.authHeaders)
      ..fields['message'] = message;
    if (photos != null) {
      request.files.addAll(photos);
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to post.');
    }
    return Map<String, dynamic>.from(body['post']);
  }

  Future<Map<String, dynamic>> likeLessonDiscussion(int discussionId, {String type = 'like'}) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionLikeUrl(discussionId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'type': type}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to react.');
    }
    return body;
  }

  Future<Map<String, dynamic>> commentLessonDiscussion(int discussionId, String comment) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionCommentUrl(discussionId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'comment': comment}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add comment.');
    }
    return Map<String, dynamic>.from(body['comment']);
  }

  Future<Map<String, dynamic>> likeLessonDiscussionComment(int commentId, {String type = 'like'}) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionCommentLikeUrl(commentId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'type': type}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to react.');
    }
    return body;
  }

  Future<Map<String, dynamic>> replyLessonDiscussionComment(int commentId, String reply) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionCommentReplyUrl(commentId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'reply': reply}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add reply.');
    }
    return Map<String, dynamic>.from(body['reply']);
  }

  Future<Map<String, dynamic>> likeLessonDiscussionReply(int replyId, {String type = 'like'}) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionReplyLikeUrl(replyId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'type': type}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to react.');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> getLessonDiscussionReactions(int discussionId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonDiscussionReactionsUrl(discussionId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load reactions.');
    }
    return List<Map<String, dynamic>>.from(body['reactions'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getLessonDiscussionCommentReactions(int commentId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonDiscussionCommentReactionsUrl(commentId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load reactions.');
    }
    return List<Map<String, dynamic>>.from(body['reactions'] ?? []);
  }

  Future<Map<String, dynamic>> replyToLessonDiscussionReply(int replyId, String reply) async {
    final res = await http
        .post(
          Uri.parse(ApiConfig.lessonDiscussionReplyReplyUrl(replyId)),
          headers: {...auth.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'reply': reply}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add reply.');
    }
    return Map<String, dynamic>.from(body['reply']);
  }

  Future<List<Map<String, dynamic>>> getLessonDiscussionReplyReactions(int replyId) async {
    final res = await http
        .get(Uri.parse(ApiConfig.lessonDiscussionReplyReactionsUrl(replyId)), headers: auth.authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load reactions.');
    }
    return List<Map<String, dynamic>>.from(body['reactions'] ?? []);
  }
}
