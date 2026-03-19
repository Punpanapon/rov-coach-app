import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:rov_coach/providers/vod_sync_provider.dart';
import 'package:rov_coach/presentation/vod_review/twitch_player.dart';

typedef OnPlaybackAction = Future<void> Function({
  required bool isPlaying,
  required double position,
});

class SmartVideoPlayerBridge {
  final ValueNotifier<bool> hasActiveVideo = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<double> position = ValueNotifier<double>(0);
  final ValueNotifier<double> duration = ValueNotifier<double>(0);

  Object? _owner;
  Future<void> Function()? togglePlayPause;
  Future<void> Function()? play;
  Future<void> Function()? pause;
  Future<void> Function(double seconds)? seekTo;

  void attach({
    required Object owner,
    required Future<void> Function() toggle,
    required Future<void> Function() play,
    required Future<void> Function() pause,
    required Future<void> Function(double seconds) seekTo,
  }) {
    _owner = owner;
    togglePlayPause = toggle;
    this.play = play;
    this.pause = pause;
    this.seekTo = seekTo;
    hasActiveVideo.value = true;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    togglePlayPause = null;
    play = null;
    pause = null;
    seekTo = null;
    hasActiveVideo.value = false;
    isPlaying.value = false;
    position.value = 0;
    duration.value = 0;
  }
}

class SmartVideoPlayer extends ConsumerWidget {
  final String url;
  final bool interactive;
  final VodSyncState? syncState;
  final String? localClientId;
  final VodSyncRole role;
  final SmartVideoPlayerBridge bridge;
  final OnPlaybackAction? onPlaybackAction;

  const SmartVideoPlayer({
    super.key,
    required this.url,
    this.interactive = true,
    required this.syncState,
    required this.localClientId,
    required this.role,
    required this.bridge,
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
        interactive: interactive && !role.isClient,
        syncState: syncState,
        localClientId: localClientId,
        role: role,
        bridge: bridge,
      );
    }

    final ytId = extractYoutubeId(url);
    if (ytId != null) {
      return IgnorePointer(
        ignoring: !interactive,
        child: _YoutubeIFramePlayer(
          videoId: ytId,
          syncState: syncState,
          localClientId: localClientId,
          role: role,
          bridge: bridge,
          onPlaybackAction: onPlaybackAction,
        ),
      );
    }

    if (_isYouTubeUrl(url)) {
      return const Center(
        child: Text('Invalid YouTube URL (Video ID not found)'),
      );
    }

    return IgnorePointer(
      ignoring: !interactive,
      child: _DirectVideoPlayer(
        url: url,
        syncState: syncState,
        localClientId: localClientId,
        role: role,
        bridge: bridge,
        onPlaybackAction: onPlaybackAction,
      ),
    );
  }
}

bool _isTwitchUrl(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null && u.host.contains('twitch.tv');
}

bool _isYouTubeUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host.contains('youtube.com') || host.contains('youtu.be');
}

String? extractYoutubeId(String url) {
  final trimmed = url.trim();
  final regExp = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=|live\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
    multiLine: false,
  );
  final match = regExp.firstMatch(trimmed);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  return null;
}

class _YoutubeIFramePlayer extends StatefulWidget {
  final String videoId;
  final VodSyncState? syncState;
  final String? localClientId;
  final VodSyncRole role;
  final SmartVideoPlayerBridge bridge;
  final OnPlaybackAction? onPlaybackAction;

  const _YoutubeIFramePlayer({
    required this.videoId,
    required this.syncState,
    required this.localClientId,
    required this.role,
    required this.bridge,
    required this.onPlaybackAction,
  });

  @override
  State<_YoutubeIFramePlayer> createState() => _YoutubeIFramePlayerState();
}

class _YoutubeIFramePlayerState extends State<_YoutubeIFramePlayer> {
  final Object _bridgeOwner = Object();
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double? _dragRatio;
  Timer? _playStatePoller;
  int _lastAppliedTimestamp = -1;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        mute: false,
      ),
    );
    _controller = controller;
    widget.bridge.attach(
      owner: _bridgeOwner,
      toggle: _togglePlayPause,
      play: _playOnly,
      pause: _pauseOnly,
      seekTo: (seconds) =>
          controller.seekTo(seconds: seconds, allowSeekAhead: true),
    );
    _stateSub?.cancel();
    _stateSub = controller.videoStateStream.listen((s) {
      if (!mounted) return;
      widget.bridge.position.value = s.position.inMilliseconds / 1000.0;
      widget.bridge.duration.value =
          controller.metadata.duration.inMilliseconds / 1000.0;
      setState(() => _position = s.position);
    });
    _playStatePoller?.cancel();
    _playStatePoller = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      final ctrl = _controller;
      if (ctrl == null) return;
      final state = await ctrl.playerState;
      if (!mounted) return;
      final nextIsPlaying = state == PlayerState.playing;
      widget.bridge.duration.value =
          ctrl.metadata.duration.inMilliseconds / 1000.0;
      if (_isPlaying != nextIsPlaying) {
        widget.bridge.isPlaying.value = nextIsPlaying;
        setState(() => _isPlaying = nextIsPlaying);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _YoutubeIFramePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _disposeController();
      _position = Duration.zero;
      _dragRatio = null;
      _isPlaying = false;
      _lastAppliedTimestamp = -1;
      _initController();
      return;
    }
    _applyRemoteSync();
  }

  Future<void> _applyRemoteSync() async {
    final sync = widget.syncState;
    if (!widget.role.isClient || sync == null || !sync.hasHost) return;
    if (sync.timestamp <= _lastAppliedTimestamp) return;
    if (sync.videoUrl.trim() != _currentUrl) return;

    _lastAppliedTimestamp = sync.timestamp;

    final incomingPlaying = sync.isPlaying;
    final localPlaying = _isPlaying;
    final ctrl = _controller;
    if (ctrl == null) return;
    if (incomingPlaying != localPlaying) {
      if (incomingPlaying) {
        await ctrl.playVideo();
      } else {
        await ctrl.pauseVideo();
      }
    }

    final localSec = _position.inMilliseconds / 1000.0;
    if ((sync.position - localSec).abs() > 1.5) {
      await ctrl.seekTo(seconds: sync.position, allowSeekAhead: true);
    }
  }

  String get _currentUrl => 'https://www.youtube.com/watch?v=${widget.videoId}';

  Future<void> _togglePlayPause() async {
    if (widget.role.isClient) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    if (_isPlaying) {
      await ctrl.pauseVideo();
    } else {
      await ctrl.playVideo();
    }
    final nextPlaying = !_isPlaying;
    widget.bridge.isPlaying.value = nextPlaying;
    setState(() => _isPlaying = nextPlaying);
    await widget.onPlaybackAction?.call(
      isPlaying: nextPlaying,
      position: _position.inMilliseconds / 1000.0,
    );
  }

  Future<void> _playOnly() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.playVideo();
    widget.bridge.isPlaying.value = true;
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _pauseOnly() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.pauseVideo();
    widget.bridge.isPlaying.value = false;
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _seekToRatio(double ratio) async {
    if (widget.role.isClient) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    final dur = ctrl.metadata.duration.inMilliseconds / 1000.0;
    if (dur <= 0) return;
    final sec = ((dur * ratio).clamp(0, dur)).toDouble();
    await ctrl.seekTo(seconds: sec, allowSeekAhead: true);
    widget.bridge.position.value = sec;
    if (mounted) setState(() => _position = Duration(milliseconds: (sec * 1000).round()));
    await widget.onPlaybackAction?.call(
      isPlaying: _isPlaying,
      position: sec,
    );
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _playStatePoller?.cancel();
    _playStatePoller = null;
    _stateSub?.cancel();
    _stateSub = null;
    _controller?.close();
    _controller = null;
    widget.bridge.detach(_bridgeOwner);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: YoutubePlayer(
            controller: ctrl,
            aspectRatio: 16 / 9,
          ),
        ),
      ],
    );
  }
}

class _DirectVideoPlayer extends StatefulWidget {
  final String url;
  final VodSyncState? syncState;
  final String? localClientId;
  final VodSyncRole role;
  final SmartVideoPlayerBridge bridge;
  final OnPlaybackAction? onPlaybackAction;

  const _DirectVideoPlayer({
    required this.url,
    required this.syncState,
    required this.localClientId,
    required this.role,
    required this.bridge,
    required this.onPlaybackAction,
  });

  @override
  State<_DirectVideoPlayer> createState() => _DirectVideoPlayerState();
}

class _DirectVideoPlayerState extends State<_DirectVideoPlayer> {
  final Object _bridgeOwner = Object();
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
      widget.bridge.attach(
        owner: _bridgeOwner,
        toggle: _toggleFromBridge,
        play: _playFromBridge,
        pause: _pauseFromBridge,
        seekTo: _seekFromBridge,
      );
      widget.bridge.isPlaying.value = _controller!.value.isPlaying;
      widget.bridge.position.value =
          _controller!.value.position.inMilliseconds / 1000.0;
      widget.bridge.duration.value =
          _controller!.value.duration.inMilliseconds / 1000.0;
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggleFromBridge() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
    } else {
      await ctrl.play();
    }
    widget.bridge.isPlaying.value = ctrl.value.isPlaying;
    widget.bridge.position.value = ctrl.value.position.inMilliseconds / 1000.0;
    widget.bridge.duration.value = ctrl.value.duration.inMilliseconds / 1000.0;
  }

  Future<void> _playFromBridge() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.play();
    widget.bridge.isPlaying.value = true;
    widget.bridge.position.value = ctrl.value.position.inMilliseconds / 1000.0;
    widget.bridge.duration.value = ctrl.value.duration.inMilliseconds / 1000.0;
  }

  Future<void> _pauseFromBridge() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.pause();
    widget.bridge.isPlaying.value = false;
    widget.bridge.position.value = ctrl.value.position.inMilliseconds / 1000.0;
    widget.bridge.duration.value = ctrl.value.duration.inMilliseconds / 1000.0;
  }

  Future<void> _seekFromBridge(double seconds) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await ctrl.seekTo(Duration(milliseconds: (seconds * 1000).round()));
    widget.bridge.position.value = seconds;
    widget.bridge.duration.value = ctrl.value.duration.inMilliseconds / 1000.0;
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
    if (ctrl == null || sync == null || !widget.role.isClient || !sync.hasHost) return;
    if (sync.videoUrl.trim() != widget.url.trim()) return;

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
      widget.bridge.isPlaying.value = ctrl.value.isPlaying;
      widget.bridge.position.value = ctrl.value.position.inMilliseconds / 1000.0;
      widget.bridge.duration.value = ctrl.value.duration.inMilliseconds / 1000.0;
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
    widget.bridge.detach(_bridgeOwner);
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
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 4),
                child: PointerInterceptor(
                  child: _DirectControls(
                    controller: ctrl,
                    controlsEnabled: !widget.role.isClient,
                    isClient: widget.role.isClient,
                    dragRatio: _dragRatio,
                    onDragRatioChanged: (v) => setState(() => _dragRatio = v),
                    onDragEnd: () => setState(() => _dragRatio = null),
                    onPlaybackAction: widget.onPlaybackAction,
                  ),
                ),
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
  final bool controlsEnabled;
  final bool isClient;
  final double? dragRatio;
  final ValueChanged<double> onDragRatioChanged;
  final VoidCallback onDragEnd;
  final OnPlaybackAction? onPlaybackAction;

  const _DirectControls({
    required this.controller,
    required this.controlsEnabled,
    required this.isClient,
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
    if (!widget.controlsEnabled) return;
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

  Future<void> _playOnly() async {
    await widget.controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _pauseOnly() async {
    await widget.controller.pause();
    if (mounted) setState(() {});
  }

  Future<void> _seekToRatio(double ratio) async {
    if (!widget.controlsEnabled) return;
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
          Expanded(
            child: Slider(
              min: 0,
              max: 1,
              value: sliderValue,
              onChanged:
                  widget.controlsEnabled ? widget.onDragRatioChanged : null,
              onChangeEnd: widget.controlsEnabled
                  ? (v) async {
                      widget.onDragEnd();
                      await _seekToRatio(v);
                    }
                  : null,
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
  final VodSyncState? syncState;
  final String? localClientId;
  final VodSyncRole role;
  final SmartVideoPlayerBridge bridge;

  const _TwitchSyncedPlayer({
    required this.videoId,
    required this.interactive,
    required this.syncState,
    required this.localClientId,
    required this.role,
    required this.bridge,
  });

  @override
  State<_TwitchSyncedPlayer> createState() => _TwitchSyncedPlayerState();
}

class _TwitchSyncedPlayerState extends State<_TwitchSyncedPlayer> {
  final Object _bridgeOwner = Object();
  Timer? _syncTimer;
  int _lastAppliedTimestamp = -1;

  @override
  void initState() {
    super.initState();
    widget.bridge.attach(
      owner: _bridgeOwner,
      toggle: _toggleFromBridge,
      play: _playFromBridge,
      pause: _pauseFromBridge,
      seekTo: _seekFromBridge,
    );
    _syncTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      _publishCurrentStateToBridge();
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
    widget.bridge.detach(_bridgeOwner);
    super.dispose();
  }

  Future<void> _toggleFromBridge() async {
    final elId = TwitchPlayerController.elementId(widget.videoId);
    final paused = TwitchPlayerController.isPaused(elId);
    if (paused) {
      TwitchPlayerController.play(elId);
    } else {
      TwitchPlayerController.pause(elId);
    }
    _publishCurrentStateToBridge();
  }

  Future<void> _playFromBridge() async {
    TwitchPlayerController.play(TwitchPlayerController.elementId(widget.videoId));
    _publishCurrentStateToBridge();
  }

  Future<void> _pauseFromBridge() async {
    TwitchPlayerController.pause(TwitchPlayerController.elementId(widget.videoId));
    _publishCurrentStateToBridge();
  }

  Future<void> _seekFromBridge(double seconds) async {
    TwitchPlayerController.seek(
      TwitchPlayerController.elementId(widget.videoId),
      seconds,
    );
    _publishCurrentStateToBridge();
  }

  void _publishCurrentStateToBridge() {
    final elId = TwitchPlayerController.elementId(widget.videoId);
    widget.bridge.isPlaying.value = !TwitchPlayerController.isPaused(elId);
    widget.bridge.position.value = TwitchPlayerController.getCurrentTime(elId);
    // Twitch iframe API bridge does not expose total duration reliably.
    widget.bridge.duration.value = 0;
  }

  void _applyRemoteSync() {
    final sync = widget.syncState;
    if (!widget.role.isClient || sync == null || !sync.hasHost) return;
    if (sync.timestamp <= _lastAppliedTimestamp) return;
    if (parseTwitchVideoId(sync.videoUrl) != widget.videoId) return;

    _lastAppliedTimestamp = sync.timestamp;

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
    return Stack(
      fit: StackFit.expand,
      children: [
        TwitchPlayer(videoId: widget.videoId, interactive: widget.interactive),
        if (widget.role.isClient)
          Positioned(
            bottom: 12,
            left: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.pause, color: Colors.white),
                    onPressed: () {
                      final elId = TwitchPlayerController.elementId(widget.videoId);
                      TwitchPlayerController.pause(elId);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      final elId = TwitchPlayerController.elementId(widget.videoId);
                      TwitchPlayerController.play(elId);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
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
