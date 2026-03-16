/// Tag for Hall of Fame/Shame entries.
enum HallTag { fame, shame }

/// A single Hall-of-Fame (or Shame) card entry.
class HallEntry {
  final String id;
  final String title;
  final String description;
  final HallTag tag;
  final String? imageUrl;
  final String? emoji;
  final DateTime createdAt;

  const HallEntry({
    required this.id,
    required this.title,
    this.description = '',
    required this.tag,
    this.imageUrl,
    this.emoji,
    required this.createdAt,
  });

  HallEntry copyWith({
    String? title,
    String? description,
    HallTag? tag,
    String? imageUrl,
    String? emoji,
  }) {
    return HallEntry(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      tag: tag ?? this.tag,
      imageUrl: imageUrl ?? this.imageUrl,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'tag': tag.name,
        'imageUrl': imageUrl,
        'emoji': emoji,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory HallEntry.fromJson(Map<String, dynamic> json) => HallEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        tag: HallTag.values.byName((json['tag'] as String?) ?? 'fame'),
        imageUrl: json['imageUrl'] as String?,
        emoji: json['emoji'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as int?) ?? 0),
      );
}
