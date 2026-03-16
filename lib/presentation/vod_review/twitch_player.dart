import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

// ── JS interop bindings for the Twitch Player bridge in index.html ──────

@JS('_createTwitchPlayer')
external void _jsCreatePlayer(
    JSString elementId, JSString videoId, JSBoolean muted, JSString? time, JSBoolean autoplay);

@JS('_destroyTwitchPlayer')
external void _jsDestroyPlayer(JSString elementId);

@JS('_getTwitchPlayerTime')
external JSNumber _jsGetPlayerTime(JSString elementId);

@JS('_isTwitchPlayerPaused')
external JSBoolean _jsIsPlayerPaused(JSString elementId);

@JS('_twitchPlayerPlay')
external void _jsPlayerPlay(JSString elementId);

@JS('_twitchPlayerPause')
external void _jsPlayerPause(JSString elementId);

@JS('_twitchPlayerSeek')
external void _jsPlayerSeek(JSString elementId, JSNumber seconds);

@JS('_twitchPlayerSkip')
external void _jsPlayerSkip(JSString elementId, JSNumber deltaSec);

/// Extracts the video ID from a Twitch VOD URL.
///
/// Supports formats:
/// - https://www.twitch.tv/videos/2715300928
/// - https://twitch.tv/videos/2715300928
/// - 2715300928  (raw ID)
String? parseTwitchVideoId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Try to match the /videos/<id> path segment
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.contains('twitch.tv')) {
    final segments = uri.pathSegments;
    final videoIdx = segments.indexOf('videos');
    if (videoIdx >= 0 && videoIdx + 1 < segments.length) {
      final id = segments[videoIdx + 1];
      if (RegExp(r'^\d+$').hasMatch(id)) return id;
    }
  }

  // Raw numeric ID
  if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;

  return null;
}

/// Convert seconds (double) to the Twitch time parameter format "0h0m0s".
String secondsToTwitchTime(double seconds) {
  final total = seconds.round().clamp(0, 999999);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return '${h}h${m}m${s}s';
}

/// Static controller for Twitch player instances.
/// Delegates to the JS bridge defined in `index.html`.
class TwitchPlayerController {
  TwitchPlayerController._();

  /// Compute the DOM element ID for a Twitch player instance.
  static String elementId(String videoId, [String? uniqueId]) {
    final suffix = uniqueId != null ? '-$uniqueId' : '';
    return 'twitch-$videoId$suffix';
  }

  static double getCurrentTime(String elId) {
    try { return _jsGetPlayerTime(elId.toJS).toDartDouble; } catch (_) { return 0; }
  }

  static bool isPaused(String elId) {
    try { return _jsIsPlayerPaused(elId.toJS).toDart; } catch (_) { return true; }
  }

  static void play(String elId) {
    try { _jsPlayerPlay(elId.toJS); } catch (_) {}
  }

  static void pause(String elId) {
    try { _jsPlayerPause(elId.toJS); } catch (_) {}
  }

  static void seek(String elId, double seconds) {
    try { _jsPlayerSeek(elId.toJS, seconds.toJS); } catch (_) {}
  }

  static void skip(String elId, double deltaSec) {
    try { _jsPlayerSkip(elId.toJS, deltaSec.toJS); } catch (_) {}
  }
}

/// Widget that embeds a Twitch VOD player using the Twitch Player JS API.
///
/// Creates a `<div>` and initialises a `Twitch.Player` instance via the JS
/// bridge in `index.html`.  Exposes programmatic control through
/// [TwitchPlayerController].
class TwitchPlayer extends StatefulWidget {
  final String videoId;

  /// When `false`, the container div gets `pointer-events: none` so Flutter
  /// widgets on top of it can receive gestures.
  final bool interactive;

  /// Optional unique suffix so multiple players for the same videoId
  /// each get their own platform view + JS player instance.
  final String? uniqueId;

  /// Start muted (bypasses browser autoplay restrictions).
  final bool muted;

  /// Initial seek position in Twitch format, e.g. "0h5m30s".
  final String? startTime;

  /// Whether the player should auto-play on creation.
  final bool autoplay;

  const TwitchPlayer({
    super.key,
    required this.videoId,
    this.interactive = true,
    this.uniqueId,
    this.muted = false,
    this.startTime,
    this.autoplay = false,
  });

  @override
  State<TwitchPlayer> createState() => _TwitchPlayerState();
}

class _TwitchPlayerState extends State<TwitchPlayer> {
  late String _viewType;
  late String _divId;
  web.HTMLDivElement? _div;

  @override
  void initState() {
    super.initState();
    _divId = TwitchPlayerController.elementId(widget.videoId, widget.uniqueId);
    _viewType = 'tw-view-$_divId';
    _register();
  }

  @override
  void didUpdateWidget(TwitchPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.uniqueId != widget.uniqueId) {
      try { _jsDestroyPlayer(_divId.toJS); } catch (_) {}
      _divId = TwitchPlayerController.elementId(widget.videoId, widget.uniqueId);
      _viewType = 'tw-view-$_divId';
      _register();
    }
    if (oldWidget.interactive != widget.interactive) {
      _div?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    }
  }

  @override
  void dispose() {
    try { _jsDestroyPlayer(_divId.toJS); } catch (_) {}
    super.dispose();
  }

  void _register() {
    final divId = _divId;
    final videoId = widget.videoId;
    final muted = widget.muted;
    final time = widget.startTime;
    final autoplay = widget.autoplay;
    final interactive = widget.interactive;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        _div = web.HTMLDivElement()
          ..id = divId
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.pointerEvents = interactive ? 'auto' : 'none';

        _jsCreatePlayer(
          divId.toJS,
          videoId.toJS,
          muted.toJS,
          time?.toJS,
          autoplay.toJS,
        );

        return _div!;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
