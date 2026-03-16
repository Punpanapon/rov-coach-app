import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:rov_coach/data/repositories/vod_board_repository.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;
import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Firestore repository singleton
// ---------------------------------------------------------------------------

final vodBoardRepositoryProvider =
    Provider<VodBoardRepository>((_) => VodBoardRepository());

// ---------------------------------------------------------------------------
// Board mode (video vs. board) — local only
// ---------------------------------------------------------------------------

final boardModeProvider =
    NotifierProvider<BoardModeNotifier, BoardMode>(BoardModeNotifier.new);

class BoardModeNotifier extends Notifier<BoardMode> {
  @override
  BoardMode build() => BoardMode.video;

  void toggle() {
    state = state == BoardMode.video ? BoardMode.board : BoardMode.video;
  }

  void set(BoardMode mode) => state = mode;
}

// ---------------------------------------------------------------------------
// Drawing tool selection — local only
// ---------------------------------------------------------------------------

final drawingToolProvider =
    NotifierProvider<DrawingToolNotifier, DrawingTool>(
        DrawingToolNotifier.new);

class DrawingToolNotifier extends Notifier<DrawingTool> {
  @override
  DrawingTool build() => DrawingTool.pen;

  void set(DrawingTool tool) => state = tool;
}

// ---------------------------------------------------------------------------
// Active pen color — local only
// ---------------------------------------------------------------------------

final activeColorProvider =
    NotifierProvider<ActiveColorNotifier, Color>(ActiveColorNotifier.new);

class ActiveColorNotifier extends Notifier<Color> {
  @override
  Color build() => const Color(0xFFFF0000);

  void set(Color c) => state = c;
}

// ---------------------------------------------------------------------------
// Active stroke width — local only
// ---------------------------------------------------------------------------

final activeStrokeWidthProvider =
    NotifierProvider<ActiveStrokeWidthNotifier, double>(
        ActiveStrokeWidthNotifier.new);

class ActiveStrokeWidthNotifier extends Notifier<double> {
  @override
  double build() => 3.0;

  void set(double w) => state = w;
}

// ---------------------------------------------------------------------------
// Permanent strokes with undo / redo history + Firestore sync
// ---------------------------------------------------------------------------

class StrokesState {
  final List<Stroke> strokes;
  final List<List<Stroke>> undoStack;
  final List<List<Stroke>> redoStack;

  const StrokesState({
    this.strokes = const [],
    this.undoStack = const [],
    this.redoStack = const [],
  });

  StrokesState copyWith({
    List<Stroke>? strokes,
    List<List<Stroke>>? undoStack,
    List<List<Stroke>>? redoStack,
  }) =>
      StrokesState(
        strokes: strokes ?? this.strokes,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
      );

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

final permanentStrokesProvider =
    NotifierProvider<PermanentStrokesNotifier, StrokesState>(
        PermanentStrokesNotifier.new);

class PermanentStrokesNotifier extends Notifier<StrokesState> {
  @override
  StrokesState build() => const StrokesState();

  void _pushUndo() {
    state = state.copyWith(
      undoStack: [...state.undoStack, List.of(state.strokes)],
      redoStack: [],
    );
  }

  void _syncToFirestore() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;
    ref.read(vodBoardRepositoryProvider).setStrokes(roomId, state.strokes);
  }

  void addStroke(Stroke stroke) {
    _pushUndo();
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _syncToFirestore();
  }

  void removeStroke(Stroke stroke) {
    _pushUndo();
    state = state.copyWith(
      strokes: state.strokes.where((s) => !identical(s, stroke)).toList(),
    );
    _syncToFirestore();
  }

  void removeStrokeAt(int index) {
    _pushUndo();
    final list = List<Stroke>.of(state.strokes)..removeAt(index);
    state = state.copyWith(strokes: list);
    _syncToFirestore();
  }

  void undo() {
    if (!state.canUndo) return;
    final previous = state.undoStack.last;
    state = state.copyWith(
      redoStack: [...state.redoStack, List.of(state.strokes)],
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      strokes: previous,
    );
    _syncToFirestore();
  }

  void redo() {
    if (!state.canRedo) return;
    final next = state.redoStack.last;
    state = state.copyWith(
      undoStack: [...state.undoStack, List.of(state.strokes)],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      strokes: next,
    );
    _syncToFirestore();
  }

  void clearAll() {
    state = const StrokesState();
    _syncToFirestore();
  }

  /// Called when a Firestore snapshot arrives from another client.
  void applyRemoteStrokes(List<Stroke> strokes) {
    state = state.copyWith(strokes: strokes);
  }
}

// ---------------------------------------------------------------------------
// Ephemeral (laser pointer) stroke — local only (not synced)
// ---------------------------------------------------------------------------

final ephemeralStrokeProvider =
    NotifierProvider<EphemeralStrokeNotifier, Stroke?>(
        EphemeralStrokeNotifier.new);

class EphemeralStrokeNotifier extends Notifier<Stroke?> {
  @override
  Stroke? build() => null;

  void start(Offset point, {Color color = const Color(0xFF00FF00), double width = 4.0}) {
    state = Stroke(
      points: [point],
      color: color,
      width: width,
      toolType: DrawingTool.laser,
    );
  }

  void addPoint(Offset point) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(points: [...s.points, point]);
  }

  void clear() => state = null;
}

// ---------------------------------------------------------------------------
// Active (in-progress) permanent stroke — local only
// ---------------------------------------------------------------------------

final activeStrokeProvider =
    NotifierProvider<ActiveStrokeNotifier, Stroke?>(
        ActiveStrokeNotifier.new);

class ActiveStrokeNotifier extends Notifier<Stroke?> {
  @override
  Stroke? build() => null;

  void start(Offset point, {Color color = const Color(0xFFFF0000), double width = 3.0, DrawingTool toolType = DrawingTool.pen}) {
    state = Stroke(
      points: [point],
      color: color,
      width: width,
      toolType: toolType,
    );
  }

  void addPoint(Offset point) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(points: [...s.points, point]);
  }

  void replacePoints(List<Offset> points) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(points: points);
  }

  Stroke? finish() {
    final s = state;
    state = null;
    return s;
  }
}

// ---------------------------------------------------------------------------
// Placed heroes on the board + Firestore sync
// ---------------------------------------------------------------------------

final placedHeroesProvider =
    NotifierProvider<PlacedHeroesNotifier, List<PlacedHero>>(
        PlacedHeroesNotifier.new);

class PlacedHeroesNotifier extends Notifier<List<PlacedHero>> {
  @override
  List<PlacedHero> build() => [];

  void _syncToFirestore() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;
    ref.read(vodBoardRepositoryProvider).setHeroes(roomId, state);
  }

  void add(String heroName, String imagePath, Offset position) {
    state = [
      ...state,
      PlacedHero(
        id: _uuid.v4(),
        heroName: heroName,
        imagePath: imagePath,
        position: position,
      ),
    ];
    _syncToFirestore();
  }

  void move(String id, Offset newPosition) {
    state = [
      for (final h in state)
        if (h.id == id) h.copyWith(position: newPosition) else h,
    ];
    _syncToFirestore();
  }

  void remove(String id) {
    state = state.where((h) => h.id != id).toList();
    _syncToFirestore();
  }

  void clearAll() {
    state = [];
    _syncToFirestore();
  }

  /// Called when a Firestore snapshot arrives from another client.
  void applyRemoteHeroes(List<PlacedHero> heroes) {
    state = heroes;
  }
}

// ---------------------------------------------------------------------------
// Hero panel collapsed state — local only
// ---------------------------------------------------------------------------

final heroPanelExpandedProvider =
    NotifierProvider<HeroPanelExpandedNotifier, bool>(
        HeroPanelExpandedNotifier.new);

class HeroPanelExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

// ---------------------------------------------------------------------------
// VOD Bookmarks + Firestore sync
// ---------------------------------------------------------------------------

final vodBookmarksProvider =
    NotifierProvider<VodBookmarksNotifier, List<VodBookmark>>(
        VodBookmarksNotifier.new);

class VodBookmarksNotifier extends Notifier<List<VodBookmark>> {
  @override
  List<VodBookmark> build() => [];

  void _syncToFirestore() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;
    ref.read(vodBoardRepositoryProvider).setBookmarks(roomId, state);
  }

  void add(VodBookmark bookmark) {
    state = [...state, bookmark];
    _syncToFirestore();
  }

  void update(VodBookmark updated) {
    state = [
      for (final b in state)
        if (b.id == updated.id) updated else b,
    ];
    _syncToFirestore();
  }

  void remove(String id) {
    state = state.where((b) => b.id != id).toList();
    _syncToFirestore();
  }

  /// Called when a Firestore snapshot arrives from another client.
  void applyRemoteBookmarks(List<VodBookmark> bookmarks) {
    state = bookmarks;
  }
}

// ---------------------------------------------------------------------------
// Firestore real-time stream providers (scoped to roomId)
// ---------------------------------------------------------------------------

/// Streams strokes from Firestore for the current room.
final firestoreStrokesProvider = StreamProvider.autoDispose<List<Stroke>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(vodBoardRepositoryProvider).strokesStream(roomId);
});

/// Streams placed heroes from Firestore for the current room.
final firestoreHeroesProvider = StreamProvider.autoDispose<List<PlacedHero>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(vodBoardRepositoryProvider).heroesStream(roomId);
});

/// Streams bookmarks from Firestore for the current room.
final firestoreBookmarksProvider = StreamProvider.autoDispose<List<VodBookmark>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(vodBoardRepositoryProvider).bookmarksStream(roomId);
});

/// Streams saved playbooks from Firestore for the current room.
final firestorePlaybooksProvider = StreamProvider.autoDispose<List<SavedPlaybook>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(vodBoardRepositoryProvider).playbooksStream(roomId);
});

// ---------------------------------------------------------------------------
// Inserted media — local only (not synced to Firestore)
// ---------------------------------------------------------------------------

final insertedMediaProvider =
    NotifierProvider<InsertedMediaNotifier, List<InsertedMedia>>(
        InsertedMediaNotifier.new);

class InsertedMediaNotifier extends Notifier<List<InsertedMedia>> {
  @override
  List<InsertedMedia> build() => [];

  void add(InsertedMedia media) {
    state = [...state, media];
  }

  void updateMedia(InsertedMedia updated) {
    state = [
      for (final m in state)
        if (m.id == updated.id) updated else m,
    ];
  }

  void move(String id, double x, double y) {
    state = [
      for (final m in state)
        if (m.id == id) m.copyWith(x: x, y: y) else m,
    ];
  }

  void resize(String id, double width, double height) {
    state = [
      for (final m in state)
        if (m.id == id) m.copyWith(width: width, height: height) else m,
    ];
  }

  void toggleLayer(String id) {
    state = [
      for (final m in state)
        if (m.id == id) m.copyWith(isBackground: !m.isBackground) else m,
    ];
  }

  void remove(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

// ---------------------------------------------------------------------------
// Blank canvas mode — local only
// ---------------------------------------------------------------------------

final blankBoardProvider =
    NotifierProvider<BlankBoardNotifier, bool>(BlankBoardNotifier.new);

class BlankBoardNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
  void toggle() => state = !state;
}

// ---------------------------------------------------------------------------
// Fullscreen state — local only
// ---------------------------------------------------------------------------

final isFullscreenProvider =
    NotifierProvider<IsFullscreenNotifier, bool>(IsFullscreenNotifier.new);

class IsFullscreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool v) => state = v;
}

// ---------------------------------------------------------------------------
// Ephemeral pen auto-vanish duration (seconds) — local only
// ---------------------------------------------------------------------------

final ephemeralDurationProvider =
    NotifierProvider<EphemeralDurationNotifier, int>(
        EphemeralDurationNotifier.new);

class EphemeralDurationNotifier extends Notifier<int> {
  @override
  int build() => 3; // default 3 seconds

  void set(int seconds) => state = seconds;
}

// ---------------------------------------------------------------------------
// Zoom-area rectangle (used only while zoomArea tool is active)
// ---------------------------------------------------------------------------

final zoomAreaRectProvider =
    NotifierProvider<ZoomAreaRectNotifier, Rect?>(ZoomAreaRectNotifier.new);

class ZoomAreaRectNotifier extends Notifier<Rect?> {
  @override
  Rect? build() => null;

  void set(Rect? r) => state = r;
  void clear() => state = null;
}

// ---------------------------------------------------------------------------
// Extracted PIP videos (live-video crop overlays) — local only
// ---------------------------------------------------------------------------

final extractedPipsProvider =
    NotifierProvider<ExtractedPipsNotifier, List<ExtractedPip>>(
        ExtractedPipsNotifier.new);

class ExtractedPipsNotifier extends Notifier<List<ExtractedPip>> {
  @override
  List<ExtractedPip> build() => [];

  void add(ExtractedPip pip) {
    state = [...state, pip];
  }

  void move(String id, double x, double y) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(x: x, y: y) else p,
    ];
  }

  void resize(String id, double width, double height) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(width: width, height: height) else p,
    ];
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  /// Reveal a pre-buffered PIP and apply its final source rect + size.
  void reveal(String id, Rect sourceRect, double width, double height) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            sourceRect: sourceRect,
            width: width,
            height: height,
            visible: true,
          )
        else
          p,
    ];
  }

  void clearAll() {
    state = [];
  }
}

// ---------------------------------------------------------------------------
// Extract-video selection rectangle (while tool is active)
// ---------------------------------------------------------------------------

final extractVideoRectProvider =
    NotifierProvider<ExtractVideoRectNotifier, Rect?>(
        ExtractVideoRectNotifier.new);

class ExtractVideoRectNotifier extends Notifier<Rect?> {
  @override
  Rect? build() => null;

  void set(Rect? r) => state = r;
  void clear() => state = null;
}

// ---------------------------------------------------------------------------
// Customizable hotkeys — persisted via SharedPreferences
// ---------------------------------------------------------------------------

/// Describes how a hotkey is triggered.
enum HotkeyType { keyboard, mouse }

class HotkeyBinding {
  final String action;
  final String label;
  final LogicalKeyboardKey key;
  final bool isCtrl;
  final bool isShift;
  final bool isAlt;
  final HotkeyType type;
  /// Mouse button index (0=left, 1=middle, 2=right) when type==mouse.
  final int mouseButton;

  const HotkeyBinding({
    required this.action,
    required this.label,
    required this.key,
    this.isCtrl = false,
    this.isShift = false,
    this.isAlt = false,
    this.type = HotkeyType.keyboard,
    this.mouseButton = 0,
  });

  HotkeyBinding copyWith({
    LogicalKeyboardKey? key,
    bool? isCtrl,
    bool? isShift,
    bool? isAlt,
    HotkeyType? type,
    int? mouseButton,
  }) =>
      HotkeyBinding(
        action: action,
        label: label,
        key: key ?? this.key,
        isCtrl: isCtrl ?? this.isCtrl,
        isShift: isShift ?? this.isShift,
        isAlt: isAlt ?? this.isAlt,
        type: type ?? this.type,
        mouseButton: mouseButton ?? this.mouseButton,
      );

  /// Readable label for the current binding.
  String get displayLabel {
    if (type == HotkeyType.mouse) {
      const names = {0: 'Left Click', 1: 'Middle Click', 2: 'Right Click'};
      final prefix = [
        if (isCtrl) 'Ctrl',
        if (isShift) 'Shift',
        if (isAlt) 'Alt',
      ].join('+');
      final btn = names[mouseButton] ?? 'Button $mouseButton';
      return prefix.isEmpty ? btn : '$prefix+$btn';
    }
    final prefix = [
      if (isCtrl) 'Ctrl',
      if (isShift) 'Shift',
      if (isAlt) 'Alt',
    ].join('+');
    final keyName = key.keyLabel;
    return prefix.isEmpty ? keyName : '$prefix+$keyName';
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'keyId': key.keyId,
        'isCtrl': isCtrl,
        'isShift': isShift,
        'isAlt': isAlt,
        'type': type.name,
        'mouseButton': mouseButton,
      };

  static HotkeyBinding fromJson(
      Map<String, dynamic> json, List<HotkeyBinding> defaults) {
    final action = json['action'] as String;
    final def = defaults.firstWhere((d) => d.action == action,
        orElse: () => defaults.first);
    final keyId = json['keyId'] as int?;
    return HotkeyBinding(
      action: action,
      label: def.label,
      key: keyId != null
          ? LogicalKeyboardKey(keyId)
          : def.key,
      isCtrl: (json['isCtrl'] as bool?) ?? false,
      isShift: (json['isShift'] as bool?) ?? false,
      isAlt: (json['isAlt'] as bool?) ?? false,
      type: (json['type'] == 'mouse') ? HotkeyType.mouse : HotkeyType.keyboard,
      mouseButton: (json['mouseButton'] as int?) ?? 0,
    );
  }
}

const _hotkeysStorageKey = 'vod_hotkeys_v2';

final hotkeysProvider =
    NotifierProvider<HotkeysNotifier, List<HotkeyBinding>>(
        HotkeysNotifier.new);

class HotkeysNotifier extends Notifier<List<HotkeyBinding>> {
  static const _defaults = [
    HotkeyBinding(
        action: 'pen', label: 'Pen', key: LogicalKeyboardKey.keyP),
    HotkeyBinding(
        action: 'laser', label: 'Laser', key: LogicalKeyboardKey.keyL),
    HotkeyBinding(
        action: 'eraser', label: 'Eraser', key: LogicalKeyboardKey.keyE),
    HotkeyBinding(
        action: 'select', label: 'Select', key: LogicalKeyboardKey.keyS),
    HotkeyBinding(
        action: 'clear',
        label: 'Clear Board',
        key: LogicalKeyboardKey.keyC),
    HotkeyBinding(
        action: 'undo',
        label: 'Undo',
        key: LogicalKeyboardKey.keyZ,
        isCtrl: true),
    HotkeyBinding(
        action: 'redo',
        label: 'Redo',
        key: LogicalKeyboardKey.keyY,
        isCtrl: true),
    HotkeyBinding(
        action: 'board_toggle',
        label: 'Toggle Board/Video',
        key: LogicalKeyboardKey.keyB),
    HotkeyBinding(
        action: 'ephemeral_pen',
        label: 'Ephemeral Pen',
        key: LogicalKeyboardKey.keyT),
    HotkeyBinding(
        action: 'zoom_area',
        label: 'Zoom Area',
        key: LogicalKeyboardKey.keyA),
    HotkeyBinding(
        action: 'play_pause',
        label: 'Play/Pause',
        key: LogicalKeyboardKey.space),
  ];

  @override
  List<HotkeyBinding> build() {
    // EMERGENCY BYPASS: Do not read from prefs to avoid JSON/Type crashes on Web.
    // _loadFromStorage();
    return List.of(_defaults);
  }

  // TODO: Re-enable once hotkey persistence is fixed for Web.
  // ignore: unused_element
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_hotkeysStorageKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) =>
              HotkeyBinding.fromJson(Map<String, dynamic>.from(e as Map), _defaults))
          .toList();
      state = list;
    } catch (e) {
      // Corrupted or incompatible data — clear it and keep defaults.
      debugPrint('[Hotkeys] Failed to load from storage, resetting: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_hotkeysStorageKey);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = state.map((b) => b.toJson()).toList();
      await prefs.setString(_hotkeysStorageKey, jsonEncode(json));
    } catch (e) {
      debugPrint('[Hotkeys] Failed to persist: $e');
    }
  }

  void rebind(String action, {
    LogicalKeyboardKey? key,
    bool? isCtrl,
    bool? isShift,
    bool? isAlt,
    HotkeyType? type,
    int? mouseButton,
  }) {
    state = [
      for (final b in state)
        if (b.action == action)
          b.copyWith(
            key: key,
            isCtrl: isCtrl,
            isShift: isShift,
            isAlt: isAlt,
            type: type,
            mouseButton: mouseButton,
          )
        else
          b,
    ];
    _persist();
  }

  void resetAll() {
    state = List.of(_defaults);
    _persist();
  }
}

// ---------------------------------------------------------------------------
// Toolbar alignment — persisted as a plain String via SharedPreferences
// ---------------------------------------------------------------------------

enum ToolbarAlignment { top, bottom, left, right }

const _toolbarAlignKey = 'vod_toolbar_align';

final toolbarAlignmentProvider =
    NotifierProvider<ToolbarAlignmentNotifier, ToolbarAlignment>(
        ToolbarAlignmentNotifier.new);

class ToolbarAlignmentNotifier extends Notifier<ToolbarAlignment> {
  @override
  ToolbarAlignment build() {
    _loadFromStorage();
    return ToolbarAlignment.top;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_toolbarAlignKey);
      if (raw != null) {
        final parsed = ToolbarAlignment.values
            .where((e) => e.name == raw)
            .firstOrNull;
        if (parsed != null) state = parsed;
      }
    } catch (e) {
      debugPrint('[ToolbarAlignment] Failed to load: $e');
    }
  }

  void set(ToolbarAlignment value) {
    state = value;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_toolbarAlignKey, state.name);
    } catch (e) {
      debugPrint('[ToolbarAlignment] Failed to persist: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Toolbar button ordering — persisted as StringList via SharedPreferences
// ---------------------------------------------------------------------------

const _toolbarOrderKey = 'vod_toolbar_order';

/// Default ordered tool identifiers.
const defaultToolbarOrder = <String>[
  'mode_video',
  'mode_board',
  'play_pause',
  'skip_back',
  'skip_forward',
  'sync_playback',
  'undo',
  'redo',
  'select',
  'pen',
  'laser',
  'rectangle',
  'circle',
  'eraser_whole',
  'eraser_partial',
  'arrow',
  'highlighter',
  'ruler',
  'ephemeral_pen',
  'zoom_area',
  'pip_crop',
  'zoom_in',
  'zoom_out',
  'zoom_reset',
  'colors',
  'stroke_width',
  'clear_board',
  'save_playbook',
  'insert_image',
  'fullscreen',
  'screen_share',
  'instant_replay',
  'broadcast',
  'watch_stream',
  'hotkey_settings',
  'customize_toolbar',
];

final toolbarOrderProvider =
    NotifierProvider<ToolbarOrderNotifier, List<String>>(
        ToolbarOrderNotifier.new);

class ToolbarOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromStorage();
    return List.of(defaultToolbarOrder);
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_toolbarOrderKey);
      if (raw != null && raw.isNotEmpty) {
        // Keep only known IDs, append any new defaults that were added later.
        final known = <String>{...defaultToolbarOrder};
        final loaded = raw.where(known.contains).toList();
        for (final id in defaultToolbarOrder) {
          if (!loaded.contains(id)) loaded.add(id);
        }
        state = loaded;
      }
    } catch (e) {
      debugPrint('[ToolbarOrder] Failed to load: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_toolbarOrderKey);
      } catch (_) {}
    }
  }

  void reorder(int oldIndex, int newIndex) {
    final list = List.of(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _persist();
  }

  void resetAll() {
    state = List.of(defaultToolbarOrder);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_toolbarOrderKey, state);
    } catch (e) {
      debugPrint('[ToolbarOrder] Failed to persist: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Toolbar enabled/disabled tools — persisted via SharedPreferences
// ---------------------------------------------------------------------------

const _enabledToolsKey = 'vod_enabled_tools';

final enabledToolsProvider =
    NotifierProvider<EnabledToolsNotifier, Set<String>>(
        EnabledToolsNotifier.new);

class EnabledToolsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFromStorage();
    return Set.of(defaultToolbarOrder); // all enabled by default
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_enabledToolsKey);
      if (raw != null) {
        state = raw.toSet();
      }
    } catch (e) {
      debugPrint('[EnabledTools] Failed to load: $e');
    }
  }

  void toggle(String id) {
    final s = Set.of(state);
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    state = s;
    _persist();
  }

  void resetAll() {
    state = Set.of(defaultToolbarOrder);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_enabledToolsKey, state.toList());
    } catch (e) {
      debugPrint('[EnabledTools] Failed to persist: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Screen Share + Instant Replay dashcam (works for host and viewers)
// ---------------------------------------------------------------------------

class ScreenShareState {
  final bool isSharing;
  final RTCVideoRenderer? renderer;
  final MediaStream? stream;
  final String? instantReplayUrl;
  final bool isPlayingReplay;
  final String? error;

  const ScreenShareState({
    this.isSharing = false,
    this.renderer,
    this.stream,
    this.instantReplayUrl,
    this.isPlayingReplay = false,
    this.error,
  });

  ScreenShareState copyWith({
    bool? isSharing,
    RTCVideoRenderer? renderer,
    MediaStream? stream,
    String? instantReplayUrl,
    bool? isPlayingReplay,
    String? error,
  }) {
    return ScreenShareState(
      isSharing: isSharing ?? this.isSharing,
      renderer: renderer ?? this.renderer,
      stream: stream ?? this.stream,
      instantReplayUrl: instantReplayUrl,
      isPlayingReplay: isPlayingReplay ?? this.isPlayingReplay,
      error: error,
    );
  }
}

final screenShareProvider =
    NotifierProvider<ScreenShareNotifier, ScreenShareState>(
        ScreenShareNotifier.new);

class ScreenShareNotifier extends Notifier<ScreenShareState> {
  web.MediaRecorder? _mediaRecorder;
  final List<web.Blob> _videoChunks = [];

  @override
  ScreenShareState build() {
    ref.onDispose(_cleanup);
    return const ScreenShareState();
  }

  Future<void> startScreenShare() async {
    if (state.isSharing) return;
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': true,
      };

      final stream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      state = ScreenShareState(
        isSharing: true,
        renderer: renderer,
        stream: stream,
        error: null,
      );
      attachDashcamStream(stream);
    } catch (e) {
      debugPrint('Display Media Error: $e');
      state = ScreenShareState(
        error:
            'Screen sharing is not supported by your browser or was denied.',
      );
      return;
    }
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(
      instantReplayUrl: state.instantReplayUrl,
      error: null,
    );
  }

  /// Public entry point for attaching any incoming stream to the local
  /// 60-second replay dashcam (host local share OR viewer remote stream).
  void attachDashcamStream(MediaStream stream) {
    _startDashcamBuffer(stream);
  }

  void _startDashcamBuffer(MediaStream stream) {
    try {
      _mediaRecorder?.stop();
    } catch (_) {}
    _mediaRecorder = null;

    _videoChunks.clear();

    try {
      final jsStream = (stream as MediaStreamWeb).jsStream;

      // Prefer VP8+Opus for browser compatibility; fallback to default.
      try {
        _mediaRecorder = web.MediaRecorder(
          jsStream,
          web.MediaRecorderOptions(mimeType: 'video/webm; codecs=vp8,opus'),
        );
      } catch (_) {
        _mediaRecorder = web.MediaRecorder(jsStream);
      }

      _mediaRecorder!.addEventListener(
        'dataavailable',
        ((web.BlobEvent event) {
          final blob = event.data;
          if (blob.size > 0) {
            _videoChunks.add(blob);
            // Keep only the last 60 chunks (~1 chunk/sec = 60 seconds)
            if (_videoChunks.length > 60) {
              _videoChunks.removeAt(0);
            }
          }
        }).toJS,
      );
      _mediaRecorder!.start(1000); // 1-second timeslice
    } catch (e) {
      debugPrint('Dashcam buffer init error: $e');
    }
  }

  void stopDashcamCapture({bool keepBuffer = true}) {
    try {
      _mediaRecorder?.stop();
    } catch (_) {}
    _mediaRecorder = null;
    if (!keepBuffer) {
      _videoChunks.clear();
    }
  }

  void triggerInstantReplay(int seconds) {
    if (_videoChunks.isEmpty) return;

    final targetChunks = seconds <= 30 && _videoChunks.length > 30
        ? _videoChunks.sublist(_videoChunks.length - 30)
        : List<web.Blob>.from(_videoChunks);

    // Revoke any previous replay URL
    _revokeReplayUrl();
    final combinedBlob =
        web.Blob(targetChunks.toJS, web.BlobPropertyBag(type: 'video/webm'));
    final url = web.URL.createObjectURL(combinedBlob);
    state = ScreenShareState(
      isSharing: state.isSharing,
      renderer: state.renderer,
      stream: state.stream,
      instantReplayUrl: url,
      isPlayingReplay: true,
      error: null,
    );
  }

  void closeReplay() {
    _revokeReplayUrl();
    state = ScreenShareState(
      isSharing: state.isSharing,
      renderer: state.renderer,
      stream: state.stream,
      error: state.error,
    );
  }

  void _revokeReplayUrl() {
    final url = state.instantReplayUrl;
    if (url != null) {
      web.URL.revokeObjectURL(url);
    }
  }

  Future<void> stopScreenShare() async {
    if (!state.isSharing) return;
    _cleanup();
    state = const ScreenShareState();
  }

  void _cleanup() {
    stopDashcamCapture(keepBuffer: false);
    _videoChunks.clear();
    _revokeReplayUrl();
    final s = state;
    s.renderer?.srcObject = null;
    s.stream?.getTracks().forEach((t) => t.stop());
    s.renderer?.dispose();
  }
}

// ---------------------------------------------------------------------------
// WebRTC P2P Broadcasting via Firestore Signaling
// ---------------------------------------------------------------------------

class P2PBroadcastState {
  final bool isBroadcasting;
  final bool isWatching;
  final RTCVideoRenderer? remoteRenderer;
  final int viewerCount;
  final String? error;

  const P2PBroadcastState({
    this.isBroadcasting = false,
    this.isWatching = false,
    this.remoteRenderer,
    this.viewerCount = 0,
    this.error,
  });
}

final p2pBroadcastProvider =
    NotifierProvider<P2PBroadcastNotifier, P2PBroadcastState>(
        P2PBroadcastNotifier.new);

class P2PBroadcastNotifier extends Notifier<P2PBroadcastState> {
  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  RTCPeerConnection? _pc;
  final List<StreamSubscription> _subs = [];

  @override
  P2PBroadcastState build() {
    ref.onDispose(_cleanup);
    return const P2PBroadcastState();
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference _signalingDoc(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('webrtc').doc('signal');

  CollectionReference _iceCandidates(String roomId, String role) =>
      _signalingDoc(roomId).collection('${role}_ice');

  // ── HOST: Start broadcasting ──

  Future<void> startBroadcast() async {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;

    final screenState = ref.read(screenShareProvider);
    if (!screenState.isSharing || screenState.stream == null) {
      state = const P2PBroadcastState(
          error: 'Start screen share first before broadcasting.');
      return;
    }

    try {
      _pc = await createPeerConnection(_iceServers);

      // Add screen share tracks to the peer connection
      for (final track in screenState.stream!.getTracks()) {
        await _pc!.addTrack(track, screenState.stream!);
      }

      // Collect host ICE candidates → Firestore
      _pc!.onIceCandidate = (RTCIceCandidate candidate) {
        _iceCandidates(roomId, 'host').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Create offer
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);

      // Write offer to Firestore
      await _signalingDoc(roomId).set({
        'offer': {'type': offer.type, 'sdp': offer.sdp},
        'hostActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Listen for viewer answer
      final answerSub = _signalingDoc(roomId).snapshots().listen((snap) async {
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null || data['answer'] == null) return;
        final answer = data['answer'] as Map<String, dynamic>;
        final remoteDesc = RTCSessionDescription(
          answer['sdp'] as String?,
          answer['type'] as String?,
        );
        if (_pc?.signalingState ==
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          await _pc!.setRemoteDescription(remoteDesc);
        }
      });
      _subs.add(answerSub);

      // Listen for viewer ICE candidates
      final viewerIceSub =
          _iceCandidates(roomId, 'viewer').snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data() as Map<String, dynamic>;
            _pc!.addCandidate(RTCIceCandidate(
              d['candidate'] as String?,
              d['sdpMid'] as String?,
              d['sdpMLineIndex'] as int?,
            ));
          }
        }
      });
      _subs.add(viewerIceSub);

      state = const P2PBroadcastState(isBroadcasting: true);
    } catch (e) {
      state = P2PBroadcastState(error: 'Broadcast error: $e');
    }
  }

  // ── VIEWER: Watch broadcast ──

  Future<void> watchBroadcast() async {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;

    try {
      // Check if host has an active offer
      final sigDoc = await _signalingDoc(roomId).get();
      final data = sigDoc.data() as Map<String, dynamic>?;
      if (data == null ||
          data['offer'] == null ||
          data['hostActive'] != true) {
        state = const P2PBroadcastState(
            error: 'No active broadcast found in this room.');
        return;
      }

      _pc = await createPeerConnection(_iceServers);

      // Remote stream → renderer
      final remoteRenderer = RTCVideoRenderer();
      await remoteRenderer.initialize();

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final remoteStream = event.streams.first;
          remoteRenderer.srcObject = remoteStream;

          // Universal dashcam: viewers also buffer what they are watching.
          ref.read(screenShareProvider.notifier).attachDashcamStream(remoteStream);

          state = P2PBroadcastState(
            isWatching: true,
            remoteRenderer: remoteRenderer,
          );
        }
      };

      // Collect viewer ICE candidates → Firestore
      _pc!.onIceCandidate = (RTCIceCandidate candidate) {
        _iceCandidates(roomId, 'viewer').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Set remote offer
      final offer = data['offer'] as Map<String, dynamic>;
      await _pc!.setRemoteDescription(RTCSessionDescription(
        offer['sdp'] as String?,
        offer['type'] as String?,
      ));

      // Create answer
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);

      // Write answer to Firestore
      await _signalingDoc(roomId).update({
        'answer': {'type': answer.type, 'sdp': answer.sdp},
      });

      // Listen for host ICE candidates
      final hostIceSub =
          _iceCandidates(roomId, 'host').snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data() as Map<String, dynamic>;
            _pc!.addCandidate(RTCIceCandidate(
              d['candidate'] as String?,
              d['sdpMid'] as String?,
              d['sdpMLineIndex'] as int?,
            ));
          }
        }
      });
      _subs.add(hostIceSub);

      state = P2PBroadcastState(
        isWatching: true,
        remoteRenderer: remoteRenderer,
      );
    } catch (e) {
      state = P2PBroadcastState(error: 'Watch error: $e');
    }
  }

  Future<void> stopBroadcast() async {
    final roomId = ref.read(roomIdProvider);
    if (roomId != null) {
      try {
        await _signalingDoc(roomId).update({'hostActive': false});
        // Clean up ICE candidates
        final hostIce = await _iceCandidates(roomId, 'host').get();
        for (final doc in hostIce.docs) {
          await doc.reference.delete();
        }
        final viewerIce = await _iceCandidates(roomId, 'viewer').get();
        for (final doc in viewerIce.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
    _cleanup();
    state = const P2PBroadcastState();
  }

  Future<void> stopWatching() async {
    ref.read(screenShareProvider.notifier).stopDashcamCapture();
    _cleanup();
    state = const P2PBroadcastState();
  }

  void _cleanup() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    final renderer = state.remoteRenderer;
    if (renderer != null) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _pc?.close();
    _pc = null;
  }
}
