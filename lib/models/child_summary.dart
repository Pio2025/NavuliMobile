class ChildSummary {
  final int userId;
  final String name;
  final String photo;
  final int schId;
  final String schoolName;

  ChildSummary({
    required this.userId,
    required this.name,
    required this.photo,
    required this.schId,
    required this.schoolName,
  });

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    return ChildSummary(
      userId: json['userId'] ?? 0,
      name: json['name'] ?? '',
      photo: json['photo'] ?? '',
      schId: json['schID'] ?? 0,
      schoolName: json['schoolName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'photo': photo,
        'schID': schId,
        'schoolName': schoolName,
      };
}
