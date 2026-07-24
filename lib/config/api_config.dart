class ApiConfig {
  static const String baseUrl = 'https://navulifiji.com';
  static const String chatSocketUrl = 'https://navuli-websocket-jg23.onrender.com';
  static const String chatSocketTokenUrl = '$baseUrl/api/chat/socket-token';

  static const String loginUrl = '$baseUrl/api/auth/login';
  static const String meUrl = '$baseUrl/api/auth/me';
  static const String noticesUrl = '$baseUrl/api/notices';
  static String noticeUrl(int id) => '$baseUrl/api/notices/$id';
  static String noticePinUrl(int id) => '$baseUrl/api/notices/$id/pin';
  static const String announcementsUrl = '$baseUrl/api/announcements';
  static String announcementUrl(int id) => '$baseUrl/api/announcements/$id';
  static const String dashboardUrl = '$baseUrl/api/dashboard';

  static const String classroomListUrl = '$baseUrl/api/classroom';
  static const String classroomStreamsUrl = '$baseUrl/api/classroom/streams';
  static String classroomUrl(int id) => '$baseUrl/api/classroom/$id';
  static String classroomSubjectsUrl(int id, {int? childId}) => childId != null
      ? '$baseUrl/api/classroom/$id/subjects?childId=$childId'
      : '$baseUrl/api/classroom/$id/subjects';
  static String classroomStaffUrl(int id) => '$baseUrl/api/classroom/$id/staff';
  static String classroomStudentsUrl(int id) => '$baseUrl/api/classroom/$id/students';
  static String classroomAttendanceUrl(int id) => '$baseUrl/api/classroom/$id/attendance';
  static String classroomAttendanceTermsUrl(int id) => '$baseUrl/api/classroom/$id/attendance/terms';
  static String classroomAttendanceDailyUrl(int id, {int? term, int? childId}) {
    final params = <String>[];
    if (term != null) params.add('term=$term');
    if (childId != null) params.add('childId=$childId');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return '$baseUrl/api/classroom/$id/attendance/daily$qs';
  }
  static String classroomAttendanceSubjectUrl(int id, {int? term, int? childId}) {
    final params = <String>[];
    if (term != null) params.add('term=$term');
    if (childId != null) params.add('childId=$childId');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return '$baseUrl/api/classroom/$id/attendance/subject$qs';
  }
  static String classroomExamUrl(int id, {int? childId}) => childId != null
      ? '$baseUrl/api/classroom/$id/exam?childId=$childId'
      : '$baseUrl/api/classroom/$id/exam';
  static String classroomDiscussionUrl(int id) => '$baseUrl/api/classroom/$id/discussion';
  static String classDiscussionPostUrl(int classId) => '$baseUrl/api/classroom/$classId/discussion';
  static String classDiscussionLikeUrl(int postId) => '$baseUrl/api/classroom/discussion/$postId/like';
  static String classDiscussionReactionsUrl(int postId) => '$baseUrl/api/classroom/discussion/$postId/reactions';
  static String classDiscussionCommentUrl(int postId) => '$baseUrl/api/classroom/discussion/$postId/comment';
  static String classDiscussionCommentLikeUrl(int commentId) => '$baseUrl/api/classroom/discussion/comment/$commentId/like';
  static String classDiscussionCommentReactionsUrl(int commentId) => '$baseUrl/api/classroom/discussion/comment/$commentId/reactions';
  static String classDiscussionCommentReplyUrl(int commentId) => '$baseUrl/api/classroom/discussion/comment/$commentId/reply';
  static String classDiscussionReplyLikeUrl(int replyId) => '$baseUrl/api/classroom/discussion/reply/$replyId/like';
  static String classDiscussionReplyReactionsUrl(int replyId) => '$baseUrl/api/classroom/discussion/reply/$replyId/reactions';
  static String classDiscussionReplyReplyUrl(int replyId) => '$baseUrl/api/classroom/discussion/reply/$replyId/reply';
  static String subjectDashboardUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/dashboard';
  static String subjectLessonsUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/lessons';
  static String subjectLessonsCalendarUrl(int classSubId, {int? term}) =>
      '$baseUrl/api/classroom/subject/$classSubId/lessons/calendar${term != null ? '?term=$term' : ''}';
  static String subjectAssignmentsUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/assignments';
  static String subjectAssignmentDetailUrl(int classSubId, int assignmentId, {int? childId}) => childId != null
      ? '$baseUrl/api/classroom/subject/$classSubId/assignment/$assignmentId?childId=$childId'
      : '$baseUrl/api/classroom/subject/$classSubId/assignment/$assignmentId';
  static String subjectFeedbackUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/feedback';

  static String lessonDetailUrl(int lessonId) => '$baseUrl/api/classroom/lesson/$lessonId';
  static String lessonQuizScoreUrl(int quizId, {int? childId}) => childId != null
      ? '$baseUrl/api/classroom/lesson/quiz/$quizId/score?childId=$childId'
      : '$baseUrl/api/classroom/lesson/quiz/$quizId/score';
  static String lessonDiscussionPostUrl(int lessonId) => '$baseUrl/api/classroom/lesson/$lessonId/discussion';
  static String lessonDiscussionFeedUrl(int lessonId) => '$baseUrl/api/classroom/lesson/$lessonId/discussion/feed';
  static String lessonDiscussionLikeUrl(int discussionId) => '$baseUrl/api/classroom/lesson/discussion/$discussionId/like';
  static String lessonDiscussionReactionsUrl(int discussionId) => '$baseUrl/api/classroom/lesson/discussion/$discussionId/reactions';
  static String lessonDiscussionCommentUrl(int discussionId) => '$baseUrl/api/classroom/lesson/discussion/$discussionId/comment';
  static String lessonDiscussionCommentLikeUrl(int commentId) => '$baseUrl/api/classroom/lesson/discussion/comment/$commentId/like';
  static String lessonDiscussionCommentReactionsUrl(int commentId) => '$baseUrl/api/classroom/lesson/discussion/comment/$commentId/reactions';
  static String lessonDiscussionCommentReplyUrl(int commentId) => '$baseUrl/api/classroom/lesson/discussion/comment/$commentId/reply';
  static String lessonDiscussionReplyLikeUrl(int replyId) => '$baseUrl/api/classroom/lesson/discussion/reply/$replyId/like';
  static String lessonDiscussionReplyReactionsUrl(int replyId) => '$baseUrl/api/classroom/lesson/discussion/reply/$replyId/reactions';
  static String lessonDiscussionReplyReplyUrl(int replyId) => '$baseUrl/api/classroom/lesson/discussion/reply/$replyId/reply';

  static String lessonFileUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl/uploads/lesson_files/$path';
  }

  static String lessonDiscussionPhotoUrl(String photo) {
    if (photo.isEmpty) return '';
    if (photo.startsWith('http://') || photo.startsWith('https://')) return photo;
    return '$baseUrl/uploads/lesson_discussion/$photo';
  }

  static const String wallFeedUrl = '$baseUrl/api/wall/feed';
  static const String wallPostUrl = '$baseUrl/api/wall/post';
  static String wallCommentsUrl(int postId) => '$baseUrl/api/wall/post/$postId/comments';
  static String wallCommentUrl(int postId) => '$baseUrl/api/wall/post/$postId/comment';
  static const String wallReactUrl = '$baseUrl/api/wall/react';

  static const String notificationsUrl = '$baseUrl/api/notifications';
  static const String notificationsMarkReadUrl = '$baseUrl/api/notifications/mark-read';

  static String photoUrl(String photo) {
    if (photo.isEmpty) return '';
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    }
    return '$baseUrl/uploads/profilePhoto/$photo';
  }

  static String discussionPhotoUrl(String photo) {
    if (photo.isEmpty) return '';
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    }
    return '$baseUrl/uploads/class_discussion/$photo';
  }

  static String schoolLogoUrl(String logo) {
    if (logo.isEmpty) return '';
    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      return logo;
    }
    return '$baseUrl/uploads/school/logo/$logo';
  }
}
