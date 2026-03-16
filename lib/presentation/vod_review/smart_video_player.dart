import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:rov_coach/providers/vod_sync_provider.dart';
import 'package:rov_coach/presentation/vod_review/twitch_player.dart';

typedef OnPlaybackAction = Future<void> Function({
  required bool isPlaying,
  required double position,
});

class SmartVideoPlayer extends ConsumerWidget {
  final String url;
  final bool interactive;
  final bool syncEnabled;
  final VodSyncState? syncState;
  final String? localClientId;
  final OnPlaybackAction? onPlaybackAction;

  const SmartVideoPlayer({
    super.key,
    required this.url,
    this.interactive = true,
    required this.syncEnabled,
    required this.syncState,
    required this.localClientId,
    this.onPlaybackAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isTwitchUrl(url)) {
      final twitchId = parseTwitchVideoId(url);
      if (twitchId == null) {
        return const Center(child: Text('Invalid Twitch URL'));
      }
      return _TwitchSyncedPlayer(
        videoId: twitchId,
        interactive: interactive,
        syncEnabled: syncEnabled,
        syncState: syncState,
        localClientId: localClientId,
      );
    }

    final ytId = _extractYouTubeId(url);
    if (ytId != null) {
      return IgnorePointer(
        ignoring: !interactive,
        child: _YoutubeIFramePlayer(
          videoId: ytId,
          syncEnabled: syncEnabled,
          syncState: syncState,
          localClientId: localClientId,
          onPlaybackAction: onPlaybackAction,
        ),
      );
    }

    return IgnorePointer(
      ignoring: !interactive,
      child: _DirectVideoPlayer(
        url: url,
        syncEnabled: syncEnabled,
        syncState: syncState,
        localClientId: localClientId,
        onPlaybackAction: onPlaybackAction,
      ),
    );
  }
}

bool _isTwitchUrl(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null && u.host.contains('twitch.tv');
}

String? _extractYouTubeId(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.first;
  }

  if (uri.host.contains('youtube.com')) {
    if (uri.pathSegments.contains('watch')) {
      return uri.queryParameters['v'];
    }
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex >= 0 && embedIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments[embedIndex + 1];
    }
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
      return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    }
  }

  return null;
}

class _YoutubeIFramePlayer extends StatefulWidget {
  final String videoId;
  final bool syncEnabled;
  final VodSyncState? syncState;
  final String? localClientId;
  final OnPlaybackAction? onPlaybackAction;

  const _YoutubeIFramePlayer({
    required this.videoId,
    required this.syncEnabled,
    required this.syncState,
    required this.localClientId,
    required this.onPlaybackAction,
  });

  @override
  State<_YoutubeIFramePlayer> createState() => _YoutubeIFramePlayerState();
}

class _YoutubeIFramePlayerState extends State<_YoutubeIFramePlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double? _dragRatio;
  Timer? _playStatePoller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: true,
      ),
    );
    _stateSub = _controller.videoStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _position = s.position);
    });
    _playStatePoller = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      final state = await _controller.playerState;
      if (!mounted) return;
      final nextIsPlaying = state == PlayerState.playing;
      if (_isPlaying != nextIsPlaying) {
        setState(() => _isPlaying = nextIsPlaying);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _YoutubeIFramePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyRemoteSync();
  }

  Future<void> _applyRemoteSync() async {
    final sync = widget.syncState;
    if (!widget.syncEnabled || sync == null) return;
    if (sync.videoUrl.trim() != _currentUrl) return;
    if (sync.updatedBy == widget.localClientId) return;

    final incomingPlaying = sync.isPlaying;
    final localPlaying = _isPlaying;
    if (incomingPlaying != localPlaying) {
      if (incomingPlaying) {
        await _controller.playVideo();
      } else {
        await _controller.pauseVideo();
      }
    }

    final localSec = _position.inMilliseconds / 1000.0;
    if ((sync.position - localSec).abs() > 1.5) {
      await _controller.seekTo(seconds: sync.position, allowSeekAhead: true);
    }
  }

  String get _currentUrl => 'https://www.youtube.com/watch?v=${widget.videoId}';

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _controller.pauseVideo();
    } else {
      await _controller.playVideo();
    }
    final nextPlaying = !_isPlaying;
    setState(() => _isPlaying = nextPlaying);
    await widget.onPlaybackAction?.call(
      isPlaying: nextPlaying,
      position: _position.inMilliseconds / 1000.0,
    );
  }

  Future<void> _seekToRatio(double ratio) async {
    final dur = _controller.metadata.duration.inMilliseconds / 1000.0;
    if (dur <= 0) return;
    final sec = ((dur * ratio).clamp(0, dur)).toDouble();
    await _controller.seekTo(seconds: sec, allowSeekAhead: true);
    if (mounted) setState(() => _position = Duration(milliseconds: (sec * 1000).round()));
    await widget.onPlaybackAction?.call(
      isPlaying: _isPlaying,
      position: sec,
    );
  }

  @override
  void dispose() {
    _playStatePoller?.cancel();
    _stateSub?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controller.metadata.duration;
    final durMs = duration.inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, durMs > 0 ? durMs : 1);
    final ratio = durMs > 0 ? posMs / durMs : 0.0;
    final sliderValue = (_dragRatio ?? ratio).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        YoutubePlayer(controller: _controller),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 1,
                    value: sliderValue,
                    onChanged: (v) => setState(() => _dragRatio = v),
                    onChangeEnd: (v) async {
                      setState(() => _dragRatio = null);
                      await _seekToRatio(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectVideoPlayer extends StatefulWidget {
  final String url;
  final bool syncEnabled;
  final VodSyncState? syncState;
  final String? localClientId;
  final OnPlaybackAction? onPlaybackAction;

  const _DirectVideoPlayer({
    required this.url,
    required this.syncEnabled,
    required this.syncState,
    required this.localClientId,
    required this.onPlaybackAction,
  });

  @override
  State<_DirectVideoPlayer> createState() => _DirectVideoPlayerState();
}

class _DirectVideoPlayerState extends State<_DirectVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initialize;
  double? _dragRatio;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize = _controller!.initialize().then((_) {
      _controller!
        ..setLooping(true)
        ..setVolume(1.0)
        ..play();
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRemoteSync();
  }

  @override
  void didUpdateWidget(covariant _DirectVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _setup();
      return;
    }
    _applyRemoteSync();
  }

  Future<void> _applyRemoteSync() async {
    final ctrl = _controller;
    final sync = widget.syncState;
    if (ctrl == null || sync == null || !widget.syncEnabled) return;
    if (sync.videoUrl.trim() != widget.url.trim()) return;
    if (sync.updatedBy == widget.localClientId) return;

    final localPos = ctrl.value.position.inMilliseconds / 1000.0;
    if ((sync.position - localPos).abs() > 1.5) {
      await ctrl.seekTo(Duration(milliseconds: (sync.position * 1000).round()));
    }

    if (sync.isPlaying != ctrl.value.isPlaying) {
      if (sync.isPlaying) {
        await ctrl.play();
      } else {
        await ctrl.pause();
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialize = null;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null || _initialize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: _DirectControls(
                controller: ctrl,
                dragRatio: _dragRatio,
                onDragRatioChanged: (v) => setState(() => _dragRatio = v),
                onDragEnd: () => setState(() => _dragRatio = null),
                onPlaybackAction: widget.onPlaybackAction,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DirectControls extends StatefulWidget {
  final VideoPlayerController controller;
  final double? dragRatio;
  final ValueChanged<double> onDragRatioChanged;
  final VoidCallback onDragEnd;
  final OnPlaybackAction? onPlaybackAction;

  const _DirectControls({
    required this.controller,
    required this.dragRatio,
    required this.onDragRatioChanged,
    required this.onDragEnd,
    required this.onPlaybackAction,
  });

  @override
  State<_DirectControls> createState() => _DirectControlsState();
}

class _DirectControlsState extends State<_DirectControls> {
  Future<void> _togglePlayPause() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    if (mounted) setState(() {});

    await widget.onPlaybackAction?.call(
      isPlaying: widget.controller.value.isPlaying,
      position: widget.controller.value.position.inMilliseconds / 1000.0,
    );
  }

  Future<void> _seekToRatio(double ratio) async {
    final durationMs = widget.controller.value.duration.inMilliseconds;
    if (durationMs <= 0) return;

    final ms = (durationMs * ratio).round();
    await widget.controller.seekTo(Duration(milliseconds: ms));

    await widget.onPlaybackAction?.call(
      isPlaying: widget.controller.value.isPlaying,
      position: ms / 1000.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.controller.value.duration.inMilliseconds;
    final posMs = widget.controller.value.position.inMilliseconds
        .clamp(0, durationMs > 0 ? durationMs : 1);
    final ratio = durationMs > 0 ? posMs / durationMs : 0.0;
    final sliderValue = (widget.dragRatio ?? ratio).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              widget.controller.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _togglePlayPause,
          ),
          SizedBox(
            width: 180,
            child: Slider(
              min: 0,
              max: 1,
              value: sliderValue,
              onChanged: widget.onDragRatioChanged,
              onChangeEnd: (v) async {
                widget.onDragEnd();
                await _seekToRatio(v);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TwitchSyncedPlayer extends StatefulWidget {
  final String videoId;
  final bool interactive;
  final bool syncEnabled;
  final VodSyncState? syncState;
  final String? localClientId;

  const _TwitchSyncedPlayer({
    required this.videoId,
    required this.interactive,
    required this.syncEnabled,
    required this.syncState,
    required this.localClientId,
  });

  @override
  State<_TwitchSyncedPlayer> createState() => _TwitchSyncedPlayerState();
}

class _TwitchSyncedPlayerState extends State<_TwitchSyncedPlayer> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      _applyRemoteSync();
    });
  }

  @override
  void didUpdateWidget(covariant _TwitchSyncedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyRemoteSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _applyRemoteSync() {
    final sync = widget.syncState;
    if (!widget.syncEnabled || sync == null) return;
    if (parseTwitchVideoId(sync.videoUrl) != widget.videoId) return;
    if (sync.updatedBy == widget.localClientId) return;

    final elId = TwitchPlayerController.elementId(widget.videoId);
    final paused = TwitchPlayerController.isPaused(elId);
    if (sync.isPlaying == paused) {
      if (sync.isPlaying) {
        TwitchPlayerController.play(elId);
      } else {
        TwitchPlayerController.pause(elId);
      }
    }

    final current = TwitchPlayerController.getCurrentTime(elId);
    if ((sync.position - current).abs() > 1.5) {
      TwitchPlayerController.seek(elId, sync.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TwitchPlayer(videoId: widget.videoId, interactive: widget.interactive);
  }
}

class GenericIFramePlayer extends StatefulWidget {
  final String url;

  const GenericIFramePlayer({super.key, required this.url});

  @override
  State<GenericIFramePlayer> createState() => _GenericIFramePlayerState();
}

class _GenericIFramePlayerState extends State<GenericIFramePlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'generic-iframe-${widget.url.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
