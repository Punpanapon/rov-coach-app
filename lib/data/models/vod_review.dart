import 'dart:typed_data';
import 'dart:ui';

/// Available drawing tool types for the tactical board.
enum DrawingTool { select, pen, laser, rectangle, circle, eraserWhole, eraserPartial, arrow, highlighter, ruler, zoomArea, ephemeralPen, extractVideo }

/// Type of media inserted onto the VOD board.
enum InsertedMediaType { image, video }

/// A user-inserted image/video placed on the VOD canvas.
/// Stored in local Riverpod state only (not synced to Firestore).
class InsertedMedia {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final InsertedMediaType type;
  final Uint8List assetBytes;
  final bool isBackground;

  const InsertedMedia({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.assetBytes,
    this.isBackground = true,
  });

  InsertedMedia copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? isBackground,
  }) {
    return InsertedMedia(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      type: type,
      assetBytes: assetBytes,
      isBackground: isBackground ?? this.isBackground,
    );
  }
}

/// A live-video PIP crop placed on the VOD canvas.
/// Uses the ClipRect illusion: a second Twitch player instance offset
/// so only the source rectangle is visible, then wrapped in a movable
/// container the coach can reposition and resize.
class ExtractedPip {
  final String id;
  /// Rectangle on the board where the user drew the extraction area.
  final Rect sourceRect;
  /// Current position / size on the board (movable + resizable).
  final double x;
  final double y;
  final double width;
  final double height;
  /// Initial seek time in Twitch format "0h5m30s".
  final String? startTime;
  /// Whether this PIP is visible (false = pre-buffering).
  final bool visible;

  const ExtractedPip({
    required this.id,
    required this.sourceRect,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.startTime,
    this.visible = true,
  });

  ExtractedPip copyWith({
    Rect? sourceRect,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? visible,
  }) {
    return ExtractedPip(
      id: id,
      sourceRect: sourceRect ?? this.sourceRect,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      startTime: startTime,
      visible: visible ?? this.visible,
    );
  }
}

/// A single drawing stroke on the VOD review canvas.
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool toolType;

  const Stroke({
    required this.points,
    this.color = const Color(0xFFFF0000),
    this.width = 3.0,
    this.toolType = DrawingTool.pen,
  });

  Stroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    DrawingTool? toolType,
  }) {
    return Stroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      toolType: toolType ?? this.toolType,
    );
  }

  /// For rectangle/circle tools the first point is the origin, last is current.
  Rect get boundingRect {
    if (points.length < 2) return Rect.zero;
    return Rect.fromPoints(points.first, points.last);
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.toARGB32(),
        'width': width,
        'toolType': toolType.name,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final toolName = json['toolType'] as String;
    final toolType = DrawingTool.values.cast<DrawingTool?>().firstWhere(
          (t) => t!.name == toolName,
          orElse: () => DrawingTool.pen,
        )!;
    return Stroke(
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['dx'] as num).toDouble(),
                (p['dy'] as num).toDouble(),
              ))
          .toList(),
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
      toolType: toolType,
    );
  }
}

/// A hero icon placed on the VOD review board.
class PlacedHero {
  final String id;
  final String heroName;
  final String imagePath;
  final Offset position;

  const PlacedHero({
    required this.id,
    required this.heroName,
    required this.imagePath,
    required this.position,
  });

  PlacedHero copyWith({Offset? position}) {
    return PlacedHero(
      id: id,
      heroName: heroName,
      imagePath: imagePath,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'heroName': heroName,
        'imagePath': imagePath,
        'dx': position.dx,
        'dy': position.dy,
      };

  factory PlacedHero.fromJson(Map<String, dynamic> json) {
    return PlacedHero(
      id: json['id'] as String,
      heroName: json['heroName'] as String,
      imagePath: json['imagePath'] as String,
      position: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
    );
  }
}

/// Interaction mode for the VOD review board.
enum BoardMode { video, board }

/// A saved VOD bookmark for quick access.
class VodBookmark {
  final String id;
  final String url;
  final String topic;
  final String notes;
  final int colorValue;

  const VodBookmark({
    required this.id,
    required this.url,
    required this.topic,
    this.notes = '',
    this.colorValue = 0xFF6C5CE7,
  });

  VodBookmark copyWith({
    String? url,
    String? topic,
    String? notes,
    int? colorValue,
  }) {
    return VodBookmark(
      id: id,
      url: url ?? this.url,
      topic: topic ?? this.topic,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'topic': topic,
        'notes': notes,
        'colorValue': colorValue,
      };

  factory VodBookmark.fromJson(Map<String, dynamic> json) => VodBookmark(
        id: json['id'] as String,
        url: json['url'] as String,
        topic: json['topic'] as String,
        notes: (json['notes'] as String?) ?? '',
        colorValue: (json['colorValue'] as int?) ?? 0xFF6C5CE7,
      );
}

/// A saved VOD playbook snapshot (strokes + heroes) stored in Firestore.
class SavedPlaybook {
  final String id;
  final String roomId;
  final String title;
  final String twitchUrl;
  final List<Stroke> strokes;
  final List<PlacedHero> heroes;
  final DateTime createdAt;

  const SavedPlaybook({
    required this.id,
    required this.roomId,
    required this.title,
    required this.twitchUrl,
    required this.strokes,
    required this.heroes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'title': title,
        'twitchUrl': twitchUrl,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'heroes': heroes.map((h) => h.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedPlaybook.fromJson(Map<String, dynamic> json) => SavedPlaybook(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        title: json['title'] as String,
        twitchUrl: json['twitchUrl'] as String,
        strokes: (json['strokes'] as List?)
                ?.map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        heroes: (json['heroes'] as List?)
                ?.map((e) => PlacedHero.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
