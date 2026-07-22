class ApiConfig {
  static const String baseUrl = 'https://navulifiji.com';

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
  static String classroomSubjectsUrl(int id) => '$baseUrl/api/classroom/$id/subjects';
  static String classroomStaffUrl(int id) => '$baseUrl/api/classroom/$id/staff';
  static String classroomStudentsUrl(int id) => '$baseUrl/api/classroom/$id/students';
  static String classroomAttendanceUrl(int id) => '$baseUrl/api/classroom/$id/attendance';
  static String classroomExamUrl(int id) => '$baseUrl/api/classroom/$id/exam';
  static String classroomDiscussionUrl(int id) => '$baseUrl/api/classroom/$id/discussion';
  static String subjectDashboardUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/dashboard';
  static String subjectLessonsUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/lessons';
  static String subjectAssignmentsUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/assignments';
  static String subjectFeedbackUrl(int classSubId) => '$baseUrl/api/classroom/subject/$classSubId/feedback';

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
