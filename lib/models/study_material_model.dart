class LessonModel {
  final int id;
  final String title;
  final String description;
  final int level;
  final bool isLocked;
  final bool isCompleted;

  LessonModel({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.isLocked,
    required this.isCompleted,
  });
}