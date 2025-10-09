class Review {
  final String employeeName;
  final String comment;
  final double rating;
  final DateTime createdAt;

  Review({
    required this.employeeName,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      employeeName: json['employee_name'] as String,
      comment: json['comment'] as String,
      rating: (json['rating'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
