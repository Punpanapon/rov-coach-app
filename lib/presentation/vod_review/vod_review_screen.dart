import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:rov_coach/data/hero_database.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/vod_sync_provider.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';
import 'package:rov_coach/providers/recording_provider.dart';
import 'package:rov_coach/presentation/vod_review/twitch_player.dart';
import 'package:rov_coach/presentation/vod_review/drawing_painter.dart';
import 'package:rov_coach/presentation/vod_review/hero_drag_panel.dart';
import 'package:rov_coach/presentation/vod_review/bookmark_dialog.dart';
import 'package:rov_coach/presentation/vod_review/moveable_media.dart';
import 'package:rov_coach/presentation/vod_review/extracted_pip_widget.dart';
import 'package:rov_coach/presentation/vod_review/smart_video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:web/web.dart' as web;

enum _VodInputMode { url, upload }

class VodReviewScreen extends ConsumerStatefulWidget {
  final String roomId;
  const VodReviewScreen({super.key, required this.roomId});

  @override
  ConsumerState<VodReviewScreen> createState() => _VodReviewScreenState();
}

class _VodReviewScreenState extends ConsumerState<VodReviewScreen> {
  final _urlController = TextEditingController();
  final _skipDurationController = TextEditingController(text: '10');
  final _skipDurationFocusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _overlayKey = GlobalKey();
  final _focusNode = FocusNode();
  final _boardViewerKey = GlobalKey();
  final _transformController = TransformationController();
  final _playerBridge = SmartVideoPlayerBridge();
  Offset? _zoomAreaStart;
  Offset? _extractVideoStart;
  String? _videoUrl;
  bool _showTrash = false;
  String _bookmarkSearch = '';
  int? _bookmarkColorFilter;
  String? _preBufferedPipId;
  _VodInputMode _vodInputMode = _VodInputMode.url;
  bool _uploadingVideo = false;

  String? get _twitchVideoId {
    final url = _videoUrl;
    if (url == null) return null;
    return parseTwitchVideoId(url);
  }

  @override
  void initState() {
    super.initState();
    _playerBridge.hasActiveVideo.addListener(_onPlayerBridgeChanged);
    _playerBridge.isPlaying.addListener(_onPlayerBridgeChanged);
    Future.microtask(() {
      if (!mounted) return;
      ref.read(roomIdProvider.notifier).set(widget.roomId);
      _hydrateFromFirestore();
    });
  }

  void _onPlayerBridgeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// One-shot fetch of VOD board state from Firestore so the board is
  /// populated immediately after a hard browser refresh.
  Future<void> _hydrateFromFirestore() async {
    final repo = ref.read(vodBoardRepositoryProvider);
    final data = await repo.loadBoard(widget.roomId);
    if (data == null || !mounted) return;

    final strokes = data['strokes'];
    if (strokes != null && (strokes as List).isNotEmpty) {
      ref.read(permanentStrokesProvider.notifier).applyRemoteStrokes(
            strokes
                .map((e) =>
                    Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
    }

    final heroes = data['heroes'];
    if (heroes != null && (heroes as List).isNotEmpty) {
      ref.read(placedHeroesProvider.notifier).applyRemoteHeroes(
            heroes
                .map((e) =>
                    PlacedHero.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
    }

    final bookmarks = data['bookmarks'];
    if (bookmarks != null && (bookmarks as List).isNotEmpty) {
      ref.read(vodBookmarksProvider.notifier).applyRemoteBookmarks(
            bookmarks
                .map((e) =>
                    VodBookmark.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
    }
  }

  @override
  void dispose() {
    _playerBridge.hasActiveVideo.removeListener(_onPlayerBridgeChanged);
    _playerBridge.isPlaying.removeListener(_onPlayerBridgeChanged);
    _urlController.dispose();
    _skipDurationController.dispose();
    _skipDurationFocusNode.dispose();
    _focusNode.dispose();
    _transformController.dispose();
    // Clear board state when leaving the VOD screen so it doesn't
    // bleed into other tabs via global providers.
    try {
      _clearLocalBoardState();
    } catch (_) {
      // Ref may already be invalid during disposal in Riverpod 3.x.
    }
    super.dispose();
  }

  void _clearLocalBoardState() {
    ref.read(permanentStrokesProvider.notifier).applyRemoteStrokes([]);
    ref.read(placedHeroesProvider.notifier).applyRemoteHeroes([]);
    ref.read(insertedMediaProvider.notifier).clearAll();
    ref.read(extractedPipsProvider.notifier).clearAll();
    ref.read(ephemeralStrokeProvider.notifier).clear();
    ref.read(activeStrokeProvider.notifier).finish();
    ref.read(boardModeProvider.notifier).set(BoardMode.video);
    ref.read(blankBoardProvider.notifier).set(false);
    ref.read(screenShareProvider.notifier).stopScreenShare();
  }

  Future<void> _insertImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      ref.read(insertedMediaProvider.notifier).add(
            InsertedMedia(
              id: const Uuid().v4(),
              x: 100,
              y: 100,
              width: 200,
              height: 150,
              type: InsertedMediaType.image,
              assetBytes: bytes,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  void _loadVideo() {
    if (ref.read(vodSyncRoleProvider).isClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Host can change the synced video.')),
      );
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a video URL')),
      );
      return;
    }

    setState(() => _videoUrl = url);
    _resetBoardForNewVideo();
    _broadcastSyncState(isPlaying: false, position: 0);
  }

  Future<void> _pickAndUploadVideo() async {
    if (ref.read(vodSyncRoleProvider).isClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Host can upload/change synced video.')),
      );
      return;
    }

    try {
      setState(() => _uploadingVideo = true);

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read selected file bytes')),
          );
        }
        return;
      }

      final ext = (file.extension ?? 'mp4').toLowerCase();
        final contentType = ext == 'm3u8' ? 'application/x-mpegURL' : 'video/mp4';
      final refPath = FirebaseStorage.instance
          .ref()
          .child('vods/${const Uuid().v4()}.$ext');

      await refPath.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await refPath.getDownloadURL();
      if (!mounted) return;
      _urlController.text = downloadUrl;
      setState(() {
        _videoUrl = downloadUrl;
      });
      _resetBoardForNewVideo();
      _broadcastSyncState(isPlaying: false, position: 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingVideo = false);
      }
    }
  }

  void _resetBoardForNewVideo() {
    ref.read(blankBoardProvider.notifier).set(false);
    ref.read(permanentStrokesProvider.notifier).clearAll();
    ref.read(ephemeralStrokeProvider.notifier).clear();
    ref.read(activeStrokeProvider.notifier).finish();
    ref.read(placedHeroesProvider.notifier).clearAll();
    ref.read(boardModeProvider.notifier).set(BoardMode.video);
  }

  Future<void> _broadcastSyncState({
    required bool isPlaying,
    required double position,
  }) async {
    final url = _videoUrl;
    if (url == null || url.trim().isEmpty) return;
    await ref.read(vodSyncControllerProvider.notifier).broadcastState(
          videoUrl: url,
          isPlaying: isPlaying,
          position: position,
        );
  }

  Future<void> _startHosting() async {
    try {
      final url = _videoUrl?.trim();
      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Load a video before starting hosting.')),
          );
        }
        return;
      }

      var isPlaying = false;
      var position = 0.0;
      if (_twitchVideoId != null) {
        final elId = TwitchPlayerController.elementId(_twitchVideoId!);
        isPlaying = !TwitchPlayerController.isPaused(elId);
        position = TwitchPlayerController.getCurrentTime(elId);
      }

      await ref.read(vodSyncControllerProvider.notifier).startHosting(
            videoUrl: url,
            isPlaying: isPlaying,
            position: position,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start host mode: $e')),
        );
      }
      rethrow;
    }
  }

  Future<void> _stopHosting() async {
    try {
      await ref.read(vodSyncControllerProvider.notifier).stopHosting();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to stop host mode: $e')),
        );
      }
      rethrow;
    }
  }

  void _watchWithHost(VodSyncState sync) {
    try {
      final incomingUrl = sync.videoUrl.trim();
      if (incomingUrl.isEmpty) return;

      setState(() {
        _videoUrl = incomingUrl;
        _urlController.text = incomingUrl;
      });
      _resetBoardForNewVideo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to watch with host: $e')),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlank = ref.watch(blankBoardProvider);
    final isFullscreen = ref.watch(isFullscreenProvider);

    // Listen to Firestore streams and push remote changes into local notifiers.
    _listenToFirestoreStreams();
    _listenToVodSync();

    return Listener(
      onPointerDown: _onPointerDown,
      child: Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: isFullscreen
            ? null
            : AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('VOD Review Board'),
                    const SizedBox(width: 8),
                    _RoomIdChip(roomId: widget.roomId),
                  ],
                ),
                actions: [
                  if (_videoUrl != null || isBlank)
                    IconButton(
                      icon: const Icon(Icons.link_off),
                      tooltip: isBlank ? 'Exit Canvas' : 'Change VOD',
                      onPressed: () {
                        setState(() => _videoUrl = null);
                        _urlController.clear();
                        ref.read(blankBoardProvider.notifier).set(false);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: 'Add Bookmark',
                    onPressed: () => _addBookmark(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmarks_outlined),
                    tooltip: 'Bookmarks',
                    onPressed: () =>
                        _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),
        endDrawer: _buildBookmarkDrawer(cs),
        body: (_videoUrl == null && !isBlank)
            ? _buildUrlInput(cs)
            : _buildBoard(cs),
      ),
    ),
    );
  }

  void _listenToVodSync() {
    ref.listen(vodSyncProvider, (_, next) {
      final role = ref.read(vodSyncRoleProvider);
      if (!role.isClient) return;

      next.whenData((sync) {
        if (sync == null) return;
        final incomingUrl = sync.videoUrl.trim();
        if (incomingUrl.isEmpty || incomingUrl == _videoUrl) return;

        setState(() {
          _videoUrl = incomingUrl;
          _urlController.text = incomingUrl;
        });
        _resetBoardForNewVideo();
      });
    });
  }

  // ── Firestore stream listener ──────────────────────────────────────
  void _listenToFirestoreStreams() {
    // Watching the stream providers inside build() ensures we re-render on
    // every Firestore snapshot.  Only apply remote data to local notifiers
    // so the UI stays reactive.
    ref.listen(firestoreStrokesProvider, (_, next) {
      next.whenData((strokes) {
        ref.read(permanentStrokesProvider.notifier).applyRemoteStrokes(strokes);
      });
    });
    ref.listen(firestoreHeroesProvider, (_, next) {
      next.whenData((heroes) {
        ref.read(placedHeroesProvider.notifier).applyRemoteHeroes(heroes);
      });
    });
    ref.listen(firestoreBookmarksProvider, (_, next) {
      next.whenData((bookmarks) {
        ref.read(vodBookmarksProvider.notifier).applyRemoteBookmarks(bookmarks);
      });
    });
  }

  // ── Bookmark helpers ─────────────────────────────────────────────────
  Future<void> _addBookmark(BuildContext ctx) async {
    final bookmark = await showBookmarkDialog(
      ctx,
      existing: null,
    );
    if (bookmark != null) {
      ref.read(vodBookmarksProvider.notifier).add(bookmark);
    }
  }

  Future<void> _saveAsPlaybook(BuildContext ctx) async {
    final titleController = TextEditingController();
    final title = await showDialog<String>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Save as Playbook'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Playbook title',
            hintText: 'e.g. Team-fight rotation at Dragon',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(titleController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();

    if (title == null || title.isEmpty) return;

    final strokes = ref.read(permanentStrokesProvider).strokes;
    final heroes = ref.read(placedHeroesProvider);
    final twitchUrl = _videoUrl ?? '';

    final playbook = SavedPlaybook(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: widget.roomId,
      title: title,
      twitchUrl: twitchUrl,
      strokes: strokes,
      heroes: heroes,
      createdAt: DateTime.now(),
    );

    ref.read(vodBoardRepositoryProvider).savePlaybook(widget.roomId, playbook);

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Playbook "$title" saved!')),
      );
    }
  }

  void _loadBookmark(VodBookmark bookmark) {
    if (ref.read(vodSyncRoleProvider).isClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Host can change the synced video.')),
      );
      return;
    }

    if (bookmark.url.trim().isNotEmpty) {
      setState(() => _videoUrl = bookmark.url.trim());
      _urlController.text = bookmark.url;
      _resetBoardForNewVideo();
      _broadcastSyncState(isPlaying: false, position: 0);
      Navigator.of(context).pop(); // close drawer
    }
  }

  Widget _buildBookmarkDrawer(ColorScheme cs) {
    final bookmarks = ref.watch(vodBookmarksProvider);

    return PointerInterceptor(
    child: Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.bookmarks, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('VOD Bookmarks',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Bookmark',
                    onPressed: () => _addBookmark(context),
                  ),
                ],
              ),
            ),
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search bookmarks…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _bookmarkSearch = v),
              ),
            ),
            // ── Color filter chips ──
            if (bookmarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildColorChip(null, cs), // "All" chip
                      ...{for (final b in bookmarks) b.colorValue}
                          .map((cv) => _buildColorChip(cv, cs)),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            if (bookmarks.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No bookmarks yet',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: Builder(builder: (context) {
                  final query = _bookmarkSearch.toLowerCase();
                  final filtered = bookmarks.where((bm) {
                    if (_bookmarkColorFilter != null &&
                        bm.colorValue != _bookmarkColorFilter) {
                      return false;
                    }
                    if (query.isNotEmpty &&
                        !bm.topic.toLowerCase().contains(query) &&
                        !bm.notes.toLowerCase().contains(query)) {
                      return false;
                    }
                    return true;
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No matching bookmarks',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  final grouped = <String, List<VodBookmark>>{};
                  for (final bm in filtered) {
                    final key = _bookmarkGroupKey(bm);
                    grouped.putIfAbsent(key, () => <VodBookmark>[]).add(bm);
                  }

                  final groupKeys = grouped.keys.toList()
                    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                  return ListView(
                    children: [
                      for (final key in groupKeys) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        for (final bm in grouped[key]!) _buildBookmarkTile(bm, cs),
                      ],
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    ),
    );
  }

  String _bookmarkGroupKey(VodBookmark bm) {
    final text = bm.topic.trim().isNotEmpty ? bm.topic.trim() : bm.notes.trim();
    if (text.isEmpty) return 'Other';

    final datePrefix = RegExp(
      r'^(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
    ).firstMatch(text);
    if (datePrefix != null) {
      return datePrefix.group(1)!;
    }

    final namePrefix = RegExp(r'^([^\s:|\-_/]+)').firstMatch(text);
    return namePrefix?.group(1) ?? 'Other';
  }

  Widget _buildBookmarkTile(VodBookmark bm, ColorScheme cs) {
    final color = Color(bm.colorValue);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(bm.topic, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: bm.notes.isNotEmpty
            ? Text(
                bm.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () async {
                final edited = await showBookmarkDialog(
                  context,
                  existing: bm,
                );
                if (edited != null) {
                  ref.read(vodBookmarksProvider.notifier).update(edited);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              onPressed: () => ref.read(vodBookmarksProvider.notifier).remove(bm.id),
            ),
          ],
        ),
        onTap: () => _loadBookmark(bm),
      ),
    );
  }

  Widget _buildColorChip(int? colorValue, ColorScheme cs) {
    final isSelected = _bookmarkColorFilter == colorValue;
    if (colorValue == null) {
      // "All" chip
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: const Text('All', style: TextStyle(fontSize: 11)),
          selected: isSelected,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _bookmarkColorFilter = null),
        ),
      );
    }
    final color = Color(colorValue);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _bookmarkColorFilter = isSelected ? null : colorValue;
        }),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? cs.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check, size: 14, color: cs.onSurface)
              : null,
        ),
      ),
    );
  }

  // ── URL input screen ──────────────────────────────────────────────────
  Widget _buildUrlInput(ColorScheme cs) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ondemand_video, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Open a VOD Source',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Use a Twitch / YouTube / direct video URL, or upload a clip.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SegmentedButton<_VodInputMode>(
                segments: const [
                  ButtonSegment<_VodInputMode>(
                    value: _VodInputMode.url,
                    icon: Icon(Icons.link),
                    label: Text('URL'),
                  ),
                  ButtonSegment<_VodInputMode>(
                    value: _VodInputMode.upload,
                    icon: Icon(Icons.upload_file),
                    label: Text('Upload'),
                  ),
                ],
                selected: {_vodInputMode},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  setState(() => _vodInputMode = selection.first);
                },
              ),
              const SizedBox(height: 16),
              if (_vodInputMode == _VodInputMode.url) ...[
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Video URL',
                    hintText: 'https://www.twitch.tv/videos/...',
                    prefixIcon: const Icon(Icons.link),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _loadVideo,
                    ),
                  ),
                  onSubmitted: (_) => _loadVideo(),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _uploadingVideo ? null : _pickAndUploadVideo,
                  icon: _uploadingVideo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_uploadingVideo
                      ? 'Uploading...'
                      : 'Choose Video and Upload'),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Or start without a video',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ref.read(blankBoardProvider.notifier).set(true);
                  ref.read(boardModeProvider.notifier).set(BoardMode.board);
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Start Blank Canvas'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main board ────────────────────────────────────────────────────────
  Widget _buildBoard(ColorScheme cs) {
    final mode = ref.watch(boardModeProvider);
    final isBoardMode = mode == BoardMode.board;
    final isBlank = ref.watch(blankBoardProvider);
    final screenShare = ref.watch(screenShareProvider);
    final p2pState = ref.watch(p2pBroadcastProvider);

    final tool = ref.watch(drawingToolProvider);
    final allowZoom = tool == DrawingTool.select;
    final zoomRect = ref.watch(zoomAreaRectProvider);
    final extractRect = ref.watch(extractVideoRectProvider);
    final extractedPips = ref.watch(extractedPipsProvider);
    final tbAlign = ref.watch(toolbarAlignmentProvider);

    final isVertical =
        tbAlign == ToolbarAlignment.left || tbAlign == ToolbarAlignment.right;

    return Stack(
      children: [
        // ── Full-area video + drawing overlay ─────────────────────────
        Positioned.fill(
          child: InteractiveViewer(
            key: _boardViewerKey,
            transformationController: _transformController,
            panEnabled: allowZoom,
            scaleEnabled: allowZoom,
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRect(
            child: Stack(
            children: [
              // Layer 1: Instant Replay OR Screen share OR Twitch OR blank.
              if (screenShare.isPlayingReplay &&
                  screenShare.instantReplayUrl != null)
                Positioned.fill(
                  child: _InstantReplayView(
                    replayUrl: screenShare.instantReplayUrl!,
                  ),
                )
              else if (screenShare.isSharing && screenShare.renderer != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: isBoardMode,
                    child: RTCVideoView(screenShare.renderer!),
                  ),
                )
              else if (p2pState.isWatching && p2pState.remoteRenderer != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: isBoardMode,
                    child: RTCVideoView(p2pState.remoteRenderer!),
                  ),
                )
              else if (isBlank)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF2D2D2D),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3A3A),
                            border: Border.all(
                                color: Colors.white10, width: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: isBoardMode,
                    child: SmartVideoPlayer(
                      url: _videoUrl!,
                      interactive: !isBoardMode,
                      syncState: ref.watch(vodSyncProvider).asData?.value,
                      localClientId:
                          ref.watch(vodSyncClientIdProvider).asData?.value,
                      role: ref.watch(vodSyncRoleProvider),
                      bridge: _playerBridge,
                      onPlaybackAction: ({required isPlaying, required position}) {
                        return _broadcastSyncState(
                          isPlaying: isPlaying,
                          position: position,
                        );
                      },
                    ),
                  ),
                ),

              // Layer 2: Drawing canvas + placed heroes + gesture detector
              if (isBoardMode)
                Positioned.fill(
                  child: PointerInterceptor(
                    child: _buildInteractiveOverlay(),
                  ),
                ),

              // Layer 3: Hero drag panel (moves to right if toolbar is left)
              if (isBoardMode)
                Positioned(
                  left: tbAlign == ToolbarAlignment.left ? null : 0,
                  right: tbAlign == ToolbarAlignment.left ? 0 : null,
                  top: 0,
                  bottom: 80,
                  child: PointerInterceptor(child: const HeroDragPanel()),
                ),

              // Layer 4: Zoom-area selection rectangle overlay
              if (zoomRect != null)
                Positioned(
                  left: zoomRect.left,
                  top: zoomRect.top,
                  width: zoomRect.width,
                  height: zoomRect.height,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent, width: 2),
                        color: Colors.cyanAccent.withAlpha(30),
                      ),
                    ),
                  ),
                ),

              // Layer 5: Extract-video selection rectangle overlay
              if (extractRect != null)
                Positioned(
                  left: extractRect.left,
                  top: extractRect.top,
                  width: extractRect.width,
                  height: extractRect.height,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orangeAccent, width: 2),
                        color: Colors.orangeAccent.withAlpha(30),
                      ),
                    ),
                  ),
                ),

              // Layer 6: Extracted PIP video widgets
              if (_twitchVideoId != null)
                for (final pip in extractedPips)
                  ExtractedPipWidget(pip: pip, videoId: _twitchVideoId!),
            ],
          ),
          ),
          ),
        ),

        // ── Static aligned toolbar ──────────────────────────────────────
        Positioned(
          top: tbAlign == ToolbarAlignment.top ? 0 : null,
          bottom: tbAlign == ToolbarAlignment.bottom ? 0 : null,
          left: tbAlign == ToolbarAlignment.left ? 0 : (tbAlign == ToolbarAlignment.top || tbAlign == ToolbarAlignment.bottom ? 0 : null),
          right: tbAlign == ToolbarAlignment.right ? 0 : (tbAlign == ToolbarAlignment.top || tbAlign == ToolbarAlignment.bottom ? 0 : null),
          child: ConstrainedBox(
            constraints: isVertical
                ? const BoxConstraints(maxWidth: 84)
                : const BoxConstraints(maxHeight: 52),
            child: PointerInterceptor(
              child: _buildToolbar(cs, mode, isVertical: isVertical),
            ),
          ),
        ),

        // ── Instant Replay close button overlay ─────────────────────────
        if (screenShare.isPlayingReplay)
          Positioned(
            top: tbAlign == ToolbarAlignment.top ? 60 : 12,
            right: 12,
            child: PointerInterceptor(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close Replay — Return to Live'),
                onPressed: () =>
                    ref.read(screenShareProvider.notifier).closeReplay(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Interactive overlay (drawing + hero targets) ──────────────────────
  Widget _buildInteractiveOverlay() {
    final strokesState = ref.watch(permanentStrokesProvider);
    final activeStroke = ref.watch(activeStrokeProvider);
    final ephemeralStroke = ref.watch(ephemeralStrokeProvider);
    final placedHeroes = ref.watch(placedHeroesProvider);
    final tool = ref.watch(drawingToolProvider);
    final allMedia = ref.watch(insertedMediaProvider);
    final backgroundMedia = allMedia.where((m) => m.isBackground).toList();
    final foregroundMedia = allMedia.where((m) => !m.isBackground).toList();

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => details.data is HeroModel,
      onAcceptWithDetails: (details) {
        final hero = details.data as HeroModel;
        final renderBox = _overlayKey.currentContext!.findRenderObject() as RenderBox;
        final localOffset = renderBox.globalToLocal(details.offset);
        const double iconSize = 48.0;
        final compensated = Offset(
          localOffset.dx - iconSize / 2,
          localOffset.dy - iconSize / 2,
        );
        ref.read(placedHeroesProvider.notifier).add(
              hero.name,
              hero.imagePath,
              compensated,
            );
      },
      builder: (context, _, _) {
        final isSelectMode = tool == DrawingTool.select;
        return Container(
          key: _overlayKey,
          color: Colors.black.withAlpha(30),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Layer A: Background media (behind drawings)
              for (final m in backgroundMedia)
                MoveableResizableMedia(media: m),
              // Layer B: Drawing strokes + gesture (IgnorePointer in select mode)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: isSelectMode,
                  child: GestureDetector(
                    behavior: isSelectMode
                        ? HitTestBehavior.translucent
                        : HitTestBehavior.opaque,
                    onPanStart: (d) => _onDrawStart(d.localPosition, tool),
                    onPanUpdate: (d) => _onDrawUpdate(d.localPosition, tool),
                    onPanEnd: (_) => _onDrawEnd(tool),
                    child: CustomPaint(
                      painter: DrawingPainter(
                        permanentStrokes: strokesState.strokes,
                        activeStroke: activeStroke,
                        ephemeralStroke: ephemeralStroke,
                      ),
                    ),
                  ),
                ),
              ),
              // Layer C: Placed heroes (always on top of drawings)
              for (final hero in placedHeroes) _buildPlacedHero(hero),
              // Layer D: Foreground media (on top of drawings)
              for (final m in foregroundMedia)
                MoveableResizableMedia(media: m),
                // Trash zone — inside the same PointerInterceptor layer
                // so it shares the event context with placed heroes.
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DragTarget<Object>(
                      onWillAcceptWithDetails: (details) => details.data is String,
                      onAcceptWithDetails: (details) {
                        ref.read(placedHeroesProvider.notifier).remove(details.data as String);
                        setState(() => _showTrash = false);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        return AnimatedOpacity(
                          opacity: _showTrash ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isHovering ? 80 : 64,
                            height: isHovering ? 80 : 64,
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.red.withAlpha(200)
                                  : Colors.red.withAlpha(120),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: isHovering ? 36 : 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlacedHero(PlacedHero hero) {
    const heroSize = 48.0;
    return Positioned(
      left: hero.position.dx,
      top: hero.position.dy,
      child: Draggable<String>(
        data: hero.id,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: _PlacedHeroIcon(hero: hero, size: heroSize),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _PlacedHeroIcon(hero: hero, size: heroSize),
        ),
        onDragStarted: () => setState(() => _showTrash = true),
        onDragEnd: (details) {
          setState(() => _showTrash = false);
          // If hero was deleted by trash, skip the move.
          final exists = ref.read(placedHeroesProvider).any((h) => h.id == hero.id);
          if (!exists) return;
          // Convert global position to local using the overlay's RenderBox
          final renderBox = _overlayKey.currentContext!.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.offset);
          final compensated = Offset(
            localOffset.dx - heroSize / 2,
            localOffset.dy - heroSize / 2,
          );
          ref.read(placedHeroesProvider.notifier).move(hero.id, compensated);
        },
        child: _PlacedHeroIcon(hero: hero, size: heroSize),
      ),
    );
  }

  // ── Drawing callbacks ─────────────────────────────────────────────────
  void _onDrawStart(Offset point, DrawingTool tool) {
    final color = ref.read(activeColorProvider);
    final width = ref.read(activeStrokeWidthProvider);

    switch (tool) {
      case DrawingTool.pen:
      case DrawingTool.arrow:
      case DrawingTool.highlighter:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.ruler:
      case DrawingTool.eraserPartial:
        ref.read(activeStrokeProvider.notifier).start(
              point,
              color: color,
              width: tool == DrawingTool.eraserPartial ? width * 4 : width,
              toolType: tool,
            );
      case DrawingTool.ephemeralPen:
        ref.read(activeStrokeProvider.notifier).start(
              point,
              color: color,
              width: width,
              toolType: DrawingTool.ephemeralPen,
            );
      case DrawingTool.laser:
        ref.read(ephemeralStrokeProvider.notifier).start(
              point,
              color: color,
              width: width,
            );
      case DrawingTool.eraserWhole:
        _eraseStrokeAt(point);
      case DrawingTool.zoomArea:
        _zoomAreaStart = point;
        ref.read(zoomAreaRectProvider.notifier).set(Rect.fromPoints(point, point));
      case DrawingTool.extractVideo:
        _extractVideoStart = point;
        ref.read(extractVideoRectProvider.notifier).set(Rect.fromPoints(point, point));
        // Auto-pause main video during crop selection
        if (_twitchVideoId != null) {
          final mainElId = TwitchPlayerController.elementId(_twitchVideoId!);
          TwitchPlayerController.pause(mainElId);

          // Pre-buffer: create a hidden PIP immediately so the iframe
          // starts loading while the user is still drawing the rectangle.
          final pipId = const Uuid().v4();
          final currentSeconds = TwitchPlayerController.getCurrentTime(mainElId);
          final timeStr = secondsToTwitchTime(currentSeconds);
          _preBufferedPipId = pipId;
          ref.read(extractedPipsProvider.notifier).add(
                ExtractedPip(
                  id: pipId,
                  sourceRect: const Rect.fromLTWH(0, 0, 320, 180),
                  x: 20,
                  y: 20,
                  width: 320,
                  height: 180,
                  startTime: timeStr,
                  visible: false,
                ),
              );
        }
      case DrawingTool.select:
        break;
    }
  }

  void _onDrawUpdate(Offset point, DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
      case DrawingTool.arrow:
      case DrawingTool.highlighter:
      case DrawingTool.eraserPartial:
      case DrawingTool.ephemeralPen:
        ref.read(activeStrokeProvider.notifier).addPoint(point);
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.ruler:
        // For shapes / ruler, keep only origin + current point
        final s = ref.read(activeStrokeProvider);
        if (s != null && s.points.isNotEmpty) {
          ref.read(activeStrokeProvider.notifier).replacePoints(
            [s.points.first, point],
          );
        }
      case DrawingTool.laser:
        ref.read(ephemeralStrokeProvider.notifier).addPoint(point);
      case DrawingTool.eraserWhole:
        _eraseStrokeAt(point);
      case DrawingTool.zoomArea:
        if (_zoomAreaStart != null) {
          ref.read(zoomAreaRectProvider.notifier)
              .set(Rect.fromPoints(_zoomAreaStart!, point));
        }
      case DrawingTool.extractVideo:
        if (_extractVideoStart != null) {
          ref.read(extractVideoRectProvider.notifier)
              .set(Rect.fromPoints(_extractVideoStart!, point));
        }
      case DrawingTool.select:
        break;
    }
  }

  void _onDrawEnd(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
      case DrawingTool.arrow:
      case DrawingTool.highlighter:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.ruler:
      case DrawingTool.eraserPartial:
        final stroke = ref.read(activeStrokeProvider.notifier).finish();
        if (stroke != null && stroke.points.length >= 2) {
          ref.read(permanentStrokesProvider.notifier).addStroke(stroke);
        }
      case DrawingTool.ephemeralPen:
        final stroke = ref.read(activeStrokeProvider.notifier).finish();
        if (stroke != null && stroke.points.length >= 2) {
          ref.read(permanentStrokesProvider.notifier).addStroke(stroke);
          // Capture value-based fingerprint (survives Firestore round-trips
          // and undo/redo which replace object references).
          final dur = ref.read(ephemeralDurationProvider);
          final firstPt = stroke.points.first;
          final lastPt = stroke.points.last;
          final ptCount = stroke.points.length;
          final sColor = stroke.color;
          final sWidth = stroke.width;
          Timer(Duration(seconds: dur), () {
            if (!mounted) return;
            final current = ref.read(permanentStrokesProvider).strokes;
            // Search from the end — most recent match is most likely.
            final i = current.lastIndexWhere((s) =>
                s.toolType == DrawingTool.ephemeralPen &&
                s.points.length == ptCount &&
                s.color == sColor &&
                s.width == sWidth &&
                s.points.first == firstPt &&
                s.points.last == lastPt);
            if (i >= 0) {
              ref.read(permanentStrokesProvider.notifier).removeStrokeAt(i);
            }
          });
        }
      case DrawingTool.laser:
        ref.read(ephemeralStrokeProvider.notifier).clear();
      case DrawingTool.eraserWhole:
        break; // erasing already happened in start/update
      case DrawingTool.zoomArea:
        _applyZoomArea();
      case DrawingTool.extractVideo:
        _applyExtractVideo();
      case DrawingTool.select:
        break;
    }
  }

  /// Whole-stroke eraser: remove any stroke within 12px of [point].
  void _eraseStrokeAt(Offset point) {
    final strokes = ref.read(permanentStrokesProvider).strokes;
    for (var i = strokes.length - 1; i >= 0; i--) {
      if (_strokeHitTest(strokes[i], point, threshold: 12)) {
        ref.read(permanentStrokesProvider.notifier).removeStrokeAt(i);
        return;
      }
    }
  }

  bool _strokeHitTest(Stroke stroke, Offset point, {double threshold = 12}) {
    for (final p in stroke.points) {
      if ((p - point).distance <= threshold) return true;
    }
    // For shapes, also check the bounding rect edges
    if (stroke.toolType == DrawingTool.rectangle ||
        stroke.toolType == DrawingTool.circle) {
      final r = stroke.boundingRect.inflate(threshold);
      if (r.contains(point)) return true;
    }
    return false;
  }

  // ── Keyboard hotkey handler (supports modifier combos) ──────────────
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final bindings = ref.read(hotkeysProvider);
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final isCtrl = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.controlRight);
    final isShift = pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight);
    final isAlt = pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.altRight);

    final match = bindings.where((b) =>
        b.type == HotkeyType.keyboard &&
        b.key == event.logicalKey &&
        b.isCtrl == isCtrl &&
        b.isShift == isShift &&
        b.isAlt == isAlt);
    if (match.isEmpty) return KeyEventResult.ignored;

    _executeHotkeyAction(match.first.action);
    return KeyEventResult.handled;
  }

  /// Handle mouse-button hotkeys via Listener.
  void _onPointerDown(PointerDownEvent event) {
    final bindings = ref.read(hotkeysProvider);
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final isCtrl = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.controlRight);
    final isShift = pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight);
    final isAlt = pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.altRight);
    final btn = event.buttons;
    // Map Flutter button bitmask to index: 1=left(0), 4=middle(1), 2=right(2)
    int btnIndex;
    if (btn & 0x02 != 0) {
      btnIndex = 2; // right
    } else if (btn & 0x04 != 0) {
      btnIndex = 1; // middle
    } else {
      btnIndex = 0; // left
    }

    final match = bindings.where((b) =>
        b.type == HotkeyType.mouse &&
        b.mouseButton == btnIndex &&
        b.isCtrl == isCtrl &&
        b.isShift == isShift &&
        b.isAlt == isAlt);
    if (match.isEmpty) return;
    _executeHotkeyAction(match.first.action);
  }

  void _executeHotkeyAction(String action) {
    switch (action) {
      case 'pen':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.pen);
      case 'laser':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.laser);
      case 'eraser':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.eraserWhole);
      case 'select':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.select);
      case 'clear':
        ref.read(permanentStrokesProvider.notifier).clearAll();
        ref.read(placedHeroesProvider.notifier).clearAll();
        ref.read(insertedMediaProvider.notifier).clearAll();
        ref.read(extractedPipsProvider.notifier).clearAll();
        ref.read(ephemeralStrokeProvider.notifier).clear();
        ref.read(activeStrokeProvider.notifier).finish();
      case 'undo':
        ref.read(permanentStrokesProvider.notifier).undo();
      case 'redo':
        ref.read(permanentStrokesProvider.notifier).redo();
      case 'board_toggle':
        final current = ref.read(boardModeProvider);
        ref.read(boardModeProvider.notifier).set(
              current == BoardMode.board ? BoardMode.video : BoardMode.board,
            );
      case 'ephemeral_pen':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.ephemeralPen);
      case 'zoom_area':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.zoomArea);
      case 'extract_video':
        ref.read(drawingToolProvider.notifier).set(DrawingTool.extractVideo);
      case 'play_pause':
        if (ref.read(vodSyncRoleProvider).isClient) return;
        if (!_playerBridge.hasActiveVideo.value) return;
        final action = _playerBridge.togglePlayPause;
        if (action == null) return;
        action().then((_) {
          _broadcastSyncState(
            isPlaying: _playerBridge.isPlaying.value,
            position: _playerBridge.position.value,
          );
        });
    }
  }

  Future<void> _seekBySeconds(double delta) async {
    if (ref.read(vodSyncRoleProvider).isClient) return;
    if (!_playerBridge.hasActiveVideo.value) return;
    final seek = _playerBridge.seekTo;
    if (seek == null) return;

    final current = _playerBridge.position.value;
    final duration = _playerBridge.duration.value;
    final maxTime = duration > 0 ? duration : 999999.0;
    final next = (current + delta).clamp(0.0, maxTime);
    await seek(next);
    _playerBridge.position.value = next;
    await _broadcastSyncState(
      isPlaying: _playerBridge.isPlaying.value,
      position: next,
    );
  }

  // ── Fullscreen toggle ─────────────────────────────────────────────
  void _toggleFullscreen() {
    final notifier = ref.read(isFullscreenProvider.notifier);
    final isFs = ref.read(isFullscreenProvider);
    if (isFs) {
      web.document.exitFullscreen();
      notifier.set(false);
    } else {
      web.document.documentElement?.requestFullscreen();
      notifier.set(true);
    }
  }

  // ── Zoom helpers ──────────────────────────────────────────────────
  void _zoomIn() {
    final current = _transformController.value.clone();
    final scale = current.getMaxScaleOnAxis();
    if (scale >= 4.0) return;
    const factor = 1.25;
    current.scaleByVector3(Vector3(factor, factor, 1));
    _transformController.value = current;
  }

  void _zoomOut() {
    final current = _transformController.value.clone();
    final scale = current.getMaxScaleOnAxis();
    if (scale <= 0.5) return;
    const factor = 0.8;
    current.scaleByVector3(Vector3(factor, factor, 1));
    _transformController.value = current;
  }

  void _zoomReset() {
    _transformController.value = Matrix4.identity();
  }

  /// Zoom to fit the drawn rectangle into the viewport.
  void _applyZoomArea() {
    final rect = ref.read(zoomAreaRectProvider);
    ref.read(zoomAreaRectProvider.notifier).clear();
    _zoomAreaStart = null;

    if (rect == null || rect.width < 10 || rect.height < 10) return;

    final viewerBox =
        _boardViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewerBox == null) return;
    final viewSize = viewerBox.size;

    final scaleX = viewSize.width / rect.width;
    final scaleY = viewSize.height / rect.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.5, 4.0);

    final matrix = Matrix4.identity();
    matrix.scaleByVector3(Vector3(scale, scale, 1));
    matrix.setTranslation(Vector3(-rect.left * scale, -rect.top * scale, 0));
    _transformController.value = matrix;
  }

  /// Create a PIP from the drawn extraction rectangle.
  void _applyExtractVideo() {
    final rect = ref.read(extractVideoRectProvider);
    ref.read(extractVideoRectProvider.notifier).clear();
    _extractVideoStart = null;

    if (rect == null || rect.width < 20 || rect.height < 20) {
      // Remove pre-buffered PIP and resume video if crop was too small
      if (_preBufferedPipId != null) {
        ref.read(extractedPipsProvider.notifier).remove(_preBufferedPipId!);
        _preBufferedPipId = null;
      }
      if (_twitchVideoId != null) {
        TwitchPlayerController.play(
            TwitchPlayerController.elementId(_twitchVideoId!));
      }
      return;
    }

    if (_twitchVideoId == null) {
      // Extracted Twitch PIP workflow is only available for Twitch VODs.
      _preBufferedPipId = null;
      return;
    }

    // Convert to local coordinates via the overlay's RenderBox
    Rect localRect = rect;
    final overlayRenderBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayRenderBox != null) {
      final topLeft = overlayRenderBox.globalToLocal(rect.topLeft);
      final bottomRight = overlayRenderBox.globalToLocal(rect.bottomRight);
      localRect = Rect.fromPoints(topLeft, bottomRight);
    }

    final normalized = Rect.fromLTWH(
      localRect.left < 0 ? 0 : localRect.left,
      localRect.top < 0 ? 0 : localRect.top,
      localRect.width,
      localRect.height,
    );

    final clipW = normalized.width.clamp(120.0, 480.0);
    final clipH = normalized.height.clamp(80.0, 360.0);

    if (_preBufferedPipId != null) {
      // Reveal the already-loading hidden PIP with the real source rect
      ref.read(extractedPipsProvider.notifier).reveal(
            _preBufferedPipId!,
            normalized,
            clipW,
            clipH,
          );
      _preBufferedPipId = null;
    } else {
      // Fallback: create fresh PIP if somehow no pre-buffer exists
      final mainElId = TwitchPlayerController.elementId(_twitchVideoId!);
      final currentSeconds = TwitchPlayerController.getCurrentTime(mainElId);
      final timeStr = secondsToTwitchTime(currentSeconds);
      ref.read(extractedPipsProvider.notifier).add(
            ExtractedPip(
              id: const Uuid().v4(),
              sourceRect: normalized,
              x: 20,
              y: 20,
              width: clipW,
              height: clipH,
              startTime: timeStr,
            ),
          );
    }

    // Switch to select to let the coach move the new PIP immediately.
    ref.read(drawingToolProvider.notifier).set(DrawingTool.select);

    // Auto-resume main video after crop
        if (_twitchVideoId != null) {
      TwitchPlayerController.play(
          TwitchPlayerController.elementId(_twitchVideoId!));
    }
  }

  // ── Top control bar ─────────────────────────────────────────────────
  Widget _buildToolbar(ColorScheme cs, BoardMode mode,
      {bool isVertical = false}) {
    final tool = ref.watch(drawingToolProvider);
    final isBoardMode = mode == BoardMode.board;
    final strokesState = ref.watch(permanentStrokesProvider);
    final toolOrder = ref.watch(toolbarOrderProvider);
    final screenShare = ref.watch(screenShareProvider);
    final p2p = ref.watch(p2pBroadcastProvider);
    final sync = ref.watch(vodSyncProvider).asData?.value;
    final role = ref.watch(vodSyncRoleProvider);
    final skipDuration = ref.watch(skipDurationProvider);
    if (!_skipDurationFocusNode.hasFocus &&
        _skipDurationController.text != '$skipDuration') {
      _skipDurationController.text = '$skipDuration';
    }

    // Map tool-id → widget builder.
    Widget? buildToolItem(String id) {
      return switch (id) {
        'mode_video' => _ToolbarToggle(
              icon: Icons.play_circle_outline,
              label: 'Video',
              selected: !isBoardMode,
              onTap: () =>
                  ref.read(boardModeProvider.notifier).set(BoardMode.video),
            ),
        'mode_board' => _ToolbarToggle(
              icon: Icons.edit,
              label: 'Board',
              selected: isBoardMode,
              onTap: () =>
                  ref.read(boardModeProvider.notifier).set(BoardMode.board),
            ),
        'play_pause' => _playerBridge.hasActiveVideo.value && !role.isClient
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolbarIcon(
                    icon: Icons.replay_10,
                    tooltip: 'Skip Backward ${skipDuration}s',
                    onTap: () => _seekBySeconds(-skipDuration.toDouble()),
                  ),
                  SizedBox(
                    width: 64,
                    height: 34,
                    child: TextField(
                      controller: _skipDurationController,
                      focusNode: _skipDurationFocusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        suffixText: 's',
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          ref.read(skipDurationProvider.notifier).set(parsed);
                        }
                      },
                      onSubmitted: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          ref.read(skipDurationProvider.notifier).set(parsed);
                        } else {
                          _skipDurationController.text =
                              '${ref.read(skipDurationProvider)}';
                        }
                      },
                    ),
                  ),
                  _ToolbarIcon(
                    icon: _playerBridge.isPlaying.value
                        ? Icons.pause
                        : Icons.play_arrow,
                    tooltip: _playerBridge.isPlaying.value ? 'Pause' : 'Play',
                    onTap: () async {
                      await _playerBridge.togglePlayPause?.call();
                      await _broadcastSyncState(
                        isPlaying: _playerBridge.isPlaying.value,
                        position: _playerBridge.position.value,
                      );
                    },
                  ),
                  _ToolbarIcon(
                    icon: Icons.forward_10,
                    tooltip: 'Skip Forward ${skipDuration}s',
                    onTap: () => _seekBySeconds(skipDuration.toDouble()),
                  ),
                ],
              )
            : null,
        'skip_back' => null,
        'skip_forward' => null,
        'sync_playback' => !role.hasHost
            ? _ToolbarIcon(
                icon: Icons.cast,
                tooltip: 'Start Hosting',
                onTap: _startHosting,
              )
            : role.isHost
                ? _ToolbarIcon(
                    icon: Icons.cancel_presentation,
                    tooltip: 'Stop Hosting',
                    onTap: _stopHosting,
                    iconColor: Colors.red,
                  )
                : _ToolbarIcon(
                    icon: Icons.cast_connected,
                    tooltip: 'Watch with ${sync?.hostName.isNotEmpty == true ? sync!.hostName : 'Host'}',
                    onTap: () {
                      final current = ref.read(vodSyncProvider).asData?.value;
                      if (current != null) {
                        _watchWithHost(current);
                      }
                    },
                    iconColor: Colors.green,
                  ),
        'undo' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.undo,
                tooltip: 'Undo',
                enabled: strokesState.canUndo,
                onTap: () =>
                    ref.read(permanentStrokesProvider.notifier).undo(),
              )
            : null,
        'redo' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.redo,
                tooltip: 'Redo',
                enabled: strokesState.canRedo,
                onTap: () =>
                    ref.read(permanentStrokesProvider.notifier).redo(),
              )
            : null,
        'select' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.near_me,
                label: 'Select',
                selected: tool == DrawingTool.select,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.select),
              )
            : null,
        'pen' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.brush,
                label: 'Pen',
                selected: tool == DrawingTool.pen,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.pen),
              )
            : null,
        'laser' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.auto_fix_high,
                label: 'Laser',
                selected: tool == DrawingTool.laser,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.laser),
              )
            : null,
        'rectangle' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.rectangle_outlined,
                label: 'Rect',
                selected: tool == DrawingTool.rectangle,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.rectangle),
              )
            : null,
        'circle' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.circle_outlined,
                label: 'Circle',
                selected: tool == DrawingTool.circle,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.circle),
              )
            : null,
        'eraser_whole' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.auto_fix_off,
                label: 'Erase',
                selected: tool == DrawingTool.eraserWhole,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.eraserWhole),
              )
            : null,
        'eraser_partial' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.deblur,
                label: 'P.Erase',
                selected: tool == DrawingTool.eraserPartial,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.eraserPartial),
              )
            : null,
        'arrow' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.arrow_forward,
                label: 'Arrow',
                selected: tool == DrawingTool.arrow,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.arrow),
              )
            : null,
        'highlighter' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.highlight,
                label: 'Highlight',
                selected: tool == DrawingTool.highlighter,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.highlighter),
              )
            : null,
        'ruler' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.radio_button_unchecked,
                label: 'Range',
                selected: tool == DrawingTool.ruler,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.ruler),
              )
            : null,
        'ephemeral_pen' => isBoardMode
            ? Flex(
                direction: isVertical ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: [
                _ToolbarToggle(
                  icon: Icons.auto_delete,
                  label: 'Vanish',
                  selected: tool == DrawingTool.ephemeralPen,
                  onTap: () => ref
                      .read(drawingToolProvider.notifier)
                      .set(DrawingTool.ephemeralPen),
                ),
                if (tool == DrawingTool.ephemeralPen)
                  _EphemeralDurationField(
                    value: ref.watch(ephemeralDurationProvider),
                    onChanged: (v) =>
                        ref.read(ephemeralDurationProvider.notifier).set(v),
                  ),
              ])
            : null,
        'zoom_area' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.crop_free,
                label: 'Zoom Area',
                selected: tool == DrawingTool.zoomArea,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.zoomArea),
              )
            : null,
        'pip_crop' => isBoardMode
            ? _ToolbarToggle(
                icon: Icons.picture_in_picture_alt,
                label: 'PIP Crop',
                selected: tool == DrawingTool.extractVideo,
                onTap: () => ref
                    .read(drawingToolProvider.notifier)
                    .set(DrawingTool.extractVideo),
              )
            : null,
        'zoom_in' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.zoom_in,
                tooltip: 'Zoom In',
                onTap: _zoomIn,
              )
            : null,
        'zoom_out' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.zoom_out,
                tooltip: 'Zoom Out',
                onTap: _zoomOut,
              )
            : null,
        'zoom_reset' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.fit_screen,
                tooltip: 'Reset Zoom',
                onTap: _zoomReset,
              )
            : null,
        'colors' => isBoardMode
            ? Wrap(
                spacing: 2,
                runSpacing: 2,
                children: _buildColorDots(cs),
              )
            : null,
        'stroke_width' => isBoardMode
            ? isVertical
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.line_weight, size: 16, color: cs.onSurface),
                    SizedBox(
                      height: 80,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: ref.watch(activeStrokeWidthProvider),
                          min: 1,
                          max: 12,
                          divisions: 11,
                          onChanged: (v) =>
                              ref.read(activeStrokeWidthProvider.notifier).set(v),
                        ),
                      ),
                    ),
                    Text(
                      '${ref.watch(activeStrokeWidthProvider).round()}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface),
                    ),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.line_weight, size: 16, color: cs.onSurface),
                    SizedBox(
                      width: 80,
                      child: Slider(
                        value: ref.watch(activeStrokeWidthProvider),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        onChanged: (v) =>
                            ref.read(activeStrokeWidthProvider.notifier).set(v),
                      ),
                    ),
                    Text(
                      '${ref.watch(activeStrokeWidthProvider).round()}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface),
                    ),
                  ])
            : null,
        'clear_board' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.delete_sweep,
                tooltip: 'Clear Board',
                onTap: () {
                  ref.read(permanentStrokesProvider.notifier).clearAll();
                  ref.read(placedHeroesProvider.notifier).clearAll();
                  ref.read(insertedMediaProvider.notifier).clearAll();
                  ref.read(extractedPipsProvider.notifier).clearAll();
                  ref.read(ephemeralStrokeProvider.notifier).clear();
                  ref.read(activeStrokeProvider.notifier).finish();
                },
              )
            : null,
        'save_playbook' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.save,
                tooltip: 'Save as Playbook',
                onTap: () => _saveAsPlaybook(context),
              )
            : null,
        'insert_image' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.add_photo_alternate,
                tooltip: 'Insert Image',
                onTap: _insertImage,
              )
            : null,
        'fullscreen' => isBoardMode
            ? _ToolbarIcon(
                icon: ref.watch(isFullscreenProvider)
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                tooltip: 'Toggle Fullscreen',
                onTap: _toggleFullscreen,
              )
            : null,
        'hotkey_settings' => isBoardMode
            ? _ToolbarIcon(
                icon: Icons.keyboard,
                tooltip: 'Hotkey Settings',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const _HotkeySettingsDialog(),
                ),
              )
            : null,
        'customize_toolbar' => _ToolbarIcon(
              icon: Icons.tune,
              tooltip: 'Customize Toolbar',
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _CustomizeToolbarDialog(),
              ),
            ),
        'screen_share' => _ToolbarToggle(
              icon: screenShare.isSharing
                  ? Icons.stop_screen_share
                  : Icons.present_to_all,
              label: screenShare.isSharing ? 'Stop Share' : 'Share',
              selected: screenShare.isSharing,
              onTap: () async {
                if (screenShare.isSharing) {
                  ref.read(screenShareProvider.notifier).stopScreenShare();
                } else {
                  await ref.read(screenShareProvider.notifier).startScreenShare();
                  final nextState = ref.read(screenShareProvider);
                  if (nextState.error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(nextState.error!)),
                    );
                    ref.read(screenShareProvider.notifier).clearError();
                  }
                }
              },
            ),
        'instant_replay' => (screenShare.isSharing || p2p.isWatching)
            ? PopupMenuButton<int>(
                tooltip: 'Instant Replay',
                onSelected: (seconds) => ref
                    .read(screenShareProvider.notifier)
                    .triggerInstantReplay(seconds),
                itemBuilder: (context) => const [
                  PopupMenuItem<int>(
                    value: 30,
                    child: Text('Replay 30s'),
                  ),
                  PopupMenuItem<int>(
                    value: 60,
                    child: Text('Replay 60s'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.replay, size: 20),
                ),
              )
            : null,
        'broadcast' => _ToolbarToggle(
              icon: p2p.isBroadcasting
                  ? Icons.cell_tower
                  : Icons.broadcast_on_personal,
              label: p2p.isBroadcasting ? 'Stop Cast' : 'Broadcast',
              selected: p2p.isBroadcasting,
              onTap: () {
                if (p2p.isBroadcasting) {
                  ref.read(p2pBroadcastProvider.notifier).stopBroadcast();
                } else {
                  ref.read(p2pBroadcastProvider.notifier).startBroadcast().then((_) {
                    final s = ref.read(p2pBroadcastProvider);
                    if (s.error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.error!)),
                      );
                    }
                  });
                }
              },
            ),
        'watch_stream' => _ToolbarToggle(
              icon: p2p.isWatching
                  ? Icons.visibility_off
                  : Icons.visibility,
              label: p2p.isWatching ? 'Stop Watch' : 'Watch',
              selected: p2p.isWatching,
              onTap: () {
                if (p2p.isWatching) {
                  ref.read(p2pBroadcastProvider.notifier).stopWatching();
                } else {
                  ref.read(p2pBroadcastProvider.notifier).watchBroadcast().then((_) {
                    final s = ref.read(p2pBroadcastProvider);
                    if (s.error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.error!)),
                      );
                    }
                  });
                }
              },
            ),
        'record_scrim' => _buildRecordButton(cs),
        _ => null, // Unknown id — skip
      };
    }

    final items = <Widget>[];
    final enabledTools = ref.watch(enabledToolsProvider);
    for (final id in toolOrder) {
      if (!enabledTools.contains(id)) continue;
      final w = buildToolItem(id);
      if (w != null) items.add(w);
    }

    final scrollDirection = isVertical ? Axis.vertical : Axis.horizontal;

    return Material(
      elevation: 2,
      color: cs.surfaceContainerHighest,
      borderRadius: switch (ref.read(toolbarAlignmentProvider)) {
        ToolbarAlignment.top =>
          const BorderRadius.vertical(bottom: Radius.circular(8)),
        ToolbarAlignment.bottom =>
          const BorderRadius.vertical(top: Radius.circular(8)),
        ToolbarAlignment.left =>
          const BorderRadius.horizontal(right: Radius.circular(8)),
        ToolbarAlignment.right =>
          const BorderRadius.horizontal(left: Radius.circular(8)),
      },
      child: SingleChildScrollView(
        scrollDirection: scrollDirection,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: isVertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    items[i],
                  ],
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    items[i],
                  ],
                ],
              ),
      ),
    );
  }

  static const _penColors = [
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF3498DB),
    Color(0xFFFFFF00),
    Color(0xFFFF6600),
    Color(0xFFFF00FF),
    Color(0xFFFFFFFF),
  ];

  List<Widget> _buildColorDots(ColorScheme cs) {
    final activeColor = ref.watch(activeColorProvider);
    return _penColors
        .map((c) => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: GestureDetector(
                onTap: () => ref.read(activeColorProvider.notifier).set(c),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: c.toARGB32() == activeColor.toARGB32()
                        ? Border.all(color: cs.onSurface, width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                  ),
                ),
              ),
            ))
        .toList();
  }

  Widget _buildRecordButton(ColorScheme cs) {
    final recordingState = ref.watch(screenRecordingProvider);
    final isRecording = recordingState.isRecording;
    final roomId = ref.watch(roomIdProvider) ?? '';

    return Tooltip(
      message: isRecording ? 'Stop Recording' : 'Record Scrim',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          try {
            if (isRecording) {
              // Stop recording
              await ref.read(screenRecordingProvider.notifier).stopRecording();
              
              // Show upload dialog after user stops recording
              if (mounted && context.mounted) {
                _showRecordingUploadDialog(roomId);
              }
            } else {
              // Start recording
              await ref.read(screenRecordingProvider.notifier).startRecording();
            }
          } catch (e) {
            if (mounted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Recording error: $e')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: isRecording
              ? _RecordingPulseButton(elapsedSeconds: recordingState.elapsedSeconds)
              : Icon(
                  Icons.circle,
                  size: 20,
                  color: Colors.red.shade600,
                ),
        ),
      ),
    );
  }

  void _showRecordingUploadDialog(String roomId) {
    final recordingState = ref.read(screenRecordingProvider);

    if (recordingState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording error: ${recordingState.errorMessage}')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordingUploadDialog(
        roomId: roomId,
        onConfirm: () {
          Navigator.of(context).pop();
          ref.read(screenRecordingProvider.notifier).uploadRecording(roomId);
        },
        onCancel: () {
          Navigator.of(context).pop();
          ref.read(screenRecordingProvider.notifier).cancelRecording();
        },
      ),
    );
  }
}

// ── Customize Toolbar dialog ────────────────────────────────────────────

/// Human-readable labels for each tool id.
const _toolLabels = <String, String>{
  'mode_video': 'Video Mode',
  'mode_board': 'Board Mode',
  'play_pause': 'Play/Pause',
  'skip_back': 'Skip Backward',
  'skip_forward': 'Skip Forward',
  'sync_playback': 'Sync Playback',
  'undo': 'Undo',
  'redo': 'Redo',
  'select': 'Select',
  'pen': 'Pen',
  'laser': 'Laser',
  'rectangle': 'Rectangle',
  'circle': 'Circle',
  'eraser_whole': 'Eraser',
  'eraser_partial': 'Partial Eraser',
  'arrow': 'Arrow',
  'highlighter': 'Highlighter',
  'ruler': 'Range / Ruler',
  'ephemeral_pen': 'Vanish Pen',
  'zoom_area': 'Zoom Area',
  'pip_crop': 'PIP Crop',
  'zoom_in': 'Zoom In',
  'zoom_out': 'Zoom Out',
  'zoom_reset': 'Reset Zoom',
  'colors': 'Color Palette',
  'stroke_width': 'Stroke Width',
  'clear_board': 'Clear Board',
  'save_playbook': 'Save Playbook',
  'insert_image': 'Insert Image',
  'fullscreen': 'Fullscreen',
  'hotkey_settings': 'Hotkey Settings',
  'customize_toolbar': 'Customize Toolbar',
  'screen_share': 'Screen Share',
  'instant_replay': 'Instant Replay',
  'record_scrim': 'Record Scrim',
};

class _CustomizeToolbarDialog extends ConsumerWidget {
  const _CustomizeToolbarDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(toolbarOrderProvider);
    final alignment = ref.watch(toolbarAlignmentProvider);
    final enabled = ref.watch(enabledToolsProvider);
    final cs = Theme.of(context).colorScheme;

    return PointerInterceptor(
      child: AlertDialog(
      title: const Text('Customize Toolbar'),
      content: SizedBox(
        width: 360,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Alignment picker ──
            Text('Toolbar Position',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            SegmentedButton<ToolbarAlignment>(
              segments: const [
                ButtonSegment(
                    value: ToolbarAlignment.top, label: Text('Top')),
                ButtonSegment(
                    value: ToolbarAlignment.bottom, label: Text('Bottom')),
                ButtonSegment(
                    value: ToolbarAlignment.left, label: Text('Left')),
                ButtonSegment(
                    value: ToolbarAlignment.right, label: Text('Right')),
              ],
              selected: {alignment},
              onSelectionChanged: (v) =>
                  ref.read(toolbarAlignmentProvider.notifier).set(v.first),
            ),
            const SizedBox(height: 16),
            Text('Button Order & Visibility',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: order.length,
                onReorder: (oldIndex, newIndex) => ref
                    .read(toolbarOrderProvider.notifier)
                    .reorder(oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final id = order[index];
                  final label = _toolLabels[id] ?? id;
                  final isEnabled = enabled.contains(id);
                  return ListTile(
                    key: ValueKey(id),
                    dense: true,
                    leading: const Icon(Icons.drag_handle, size: 20),
                    title: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          color: isEnabled
                              ? cs.onSurface
                              : cs.onSurface.withAlpha(100),
                        )),
                    trailing: Switch(
                      value: isEnabled,
                      onChanged: (_) =>
                          ref.read(enabledToolsProvider.notifier).toggle(id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(toolbarOrderProvider.notifier).resetAll();
            ref.read(enabledToolsProvider.notifier).resetAll();
            ref.read(toolbarAlignmentProvider.notifier).set(ToolbarAlignment.top);
          },
          child: const Text('Reset Defaults'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
    );
  }
}

// ── Play/Pause master button ────────────────────────────────────────────

class _PlayPauseButton extends StatefulWidget {
  final String videoId;
  final void Function({required bool isPlaying, required double position})?
      onPlaybackAction;

  const _PlayPauseButton({
    required this.videoId,
    this.onPlaybackAction,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  Timer? _pollTimer;
  bool _paused = true;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (!mounted) return;
        final elId = TwitchPlayerController.elementId(widget.videoId);
        final p = TwitchPlayerController.isPaused(elId);
        if (p != _paused) setState(() => _paused = p);
      },
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    final elId = TwitchPlayerController.elementId(widget.videoId);
    // Immediately flip local state for responsiveness.
    final wasPaused = _paused;
    setState(() => _paused = !_paused);
    try {
      if (wasPaused) {
        TwitchPlayerController.play(elId);
      } else {
        TwitchPlayerController.pause(elId);
      }
      final position = TwitchPlayerController.getCurrentTime(elId);
      widget.onPlaybackAction?.call(
        isPlaying: wasPaused,
        position: position,
      );
    } catch (e) {
      debugPrint('Twitch Controller Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PointerInterceptor(
      child: Tooltip(
        message: _paused ? 'Play' : 'Pause',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              _paused ? Icons.play_arrow : Icons.pause,
              size: 22,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skip Forward / Backward button ──────────────────────────────────────

class _SkipButton extends StatefulWidget {
  final String videoId;
  final bool forward;
  final void Function({required bool isPlaying, required double position})?
      onPlaybackAction;

  const _SkipButton({
    required this.videoId,
    required this.forward,
    this.onPlaybackAction,
  });

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  int _skipSec = 10;

  void _skip() {
    final elId = TwitchPlayerController.elementId(widget.videoId);
    TwitchPlayerController.skip(
        elId, widget.forward ? _skipSec.toDouble() : -_skipSec.toDouble());
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final position = TwitchPlayerController.getCurrentTime(elId);
      final isPlaying = !TwitchPlayerController.isPaused(elId);
      widget.onPlaybackAction?.call(
        isPlaying: isPlaying,
        position: position,
      );
    });
  }

  void _editDuration() async {
    final ctrl = TextEditingController(text: '$_skipSec');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Set ${widget.forward ? "Forward" : "Backward"} Skip (seconds)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Seconds',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text);
                if (n != null && n > 0) Navigator.pop(ctx, n);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _skipSec = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PointerInterceptor(
      child: Tooltip(
        message:
            '${widget.forward ? "Forward" : "Backward"} ${_skipSec}s\n(Right-click to change)',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          onSecondaryTap: _editDuration,
          onLongPress: _editDuration,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.forward ? Icons.forward_10 : Icons.replay_10,
                    size: 20,
                    color: cs.onSurface,
                  ),
                  if (_skipSec != 10)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        '${_skipSec}s',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small widgets ───────────────────────────────────────────────────────

class _ToolbarToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final FutureOr<void> Function() onTap;

  const _ToolbarToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          try {
            await onTap();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Action failed: $e')),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurface),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final FutureOr<void> Function() onTap;
  final bool enabled;
  final Color? iconColor;

  const _ToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled
            ? () async {
                try {
                  await onTap();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Action failed: $e')),
                    );
                  }
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? (iconColor ?? cs.onSurface)
                : cs.onSurface.withAlpha(80),
          ),
        ),
      ),
    );
  }
}

class _PlacedHeroIcon extends StatelessWidget {
  final PlacedHero hero;
  final double size;

  const _PlacedHeroIcon({required this.hero, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          hero.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.grey.shade800,
            alignment: Alignment.center,
            child: Text(
              hero.heroName[0],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the shortened room ID as a chip in the AppBar.
class _RoomIdChip extends StatelessWidget {
  final String roomId;
  const _RoomIdChip({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final short = roomId.length > 8 ? roomId.substring(0, 8) : roomId;
    return Tooltip(
      message: 'Room: $roomId\nShare this URL to collaborate',
      child: Chip(
        avatar: Icon(Icons.group, size: 14,
            color: Theme.of(context).colorScheme.primary),
        label: Text(short, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ── Ephemeral Duration Field ────────────────────────────────────────────

class _EphemeralDurationField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _EphemeralDurationField({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_EphemeralDurationField> createState() =>
      _EphemeralDurationFieldState();
}

class _EphemeralDurationFieldState extends State<_EphemeralDurationField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_EphemeralDurationField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text);
    if (v != null && v >= 1 && v <= 60) {
      widget.onChanged(v);
    } else {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: 48,
        height: 28,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurface),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            suffixText: 's',
            suffixStyle: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _submit(),
          onEditingComplete: _submit,
        ),
      ),
    );
  }
}

// ── Hotkey Settings Dialog ──────────────────────────────────────────────

class _HotkeySettingsDialog extends ConsumerStatefulWidget {
  const _HotkeySettingsDialog();

  @override
  ConsumerState<_HotkeySettingsDialog> createState() =>
      _HotkeySettingsDialogState();
}

class _HotkeySettingsDialogState extends ConsumerState<_HotkeySettingsDialog> {
  int? _listeningIndex;

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(hotkeysProvider);
    final cs = Theme.of(context).colorScheme;

    return PointerInterceptor(
      child: AlertDialog(
        title: const Text('Hotkey Settings'),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: bindings.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = bindings[i];
              final isListening = _listeningIndex == i;

              return ListTile(
                dense: true,
                title: Text(b.label),
                trailing: isListening
                    ? Listener(
                        onPointerDown: (event) {
                          // Capture mouse button binding
                          final pressedKeys =
                              HardwareKeyboard.instance.logicalKeysPressed;
                          final isCtrl = pressedKeys.contains(
                                  LogicalKeyboardKey.controlLeft) ||
                              pressedKeys.contains(
                                  LogicalKeyboardKey.controlRight);
                          final isShift = pressedKeys.contains(
                                  LogicalKeyboardKey.shiftLeft) ||
                              pressedKeys.contains(
                                  LogicalKeyboardKey.shiftRight);
                          final isAlt = pressedKeys.contains(
                                  LogicalKeyboardKey.altLeft) ||
                              pressedKeys
                                  .contains(LogicalKeyboardKey.altRight);
                          int btnIndex;
                          if (event.buttons & 0x02 != 0) {
                            btnIndex = 2;
                          } else if (event.buttons & 0x04 != 0) {
                            btnIndex = 1;
                          } else {
                            btnIndex = 0;
                          }
                          // Only bind non-left or modified clicks as mouse
                          if (btnIndex != 0 || isCtrl || isShift || isAlt) {
                            ref.read(hotkeysProvider.notifier).rebind(
                                  b.action,
                                  type: HotkeyType.mouse,
                                  mouseButton: btnIndex,
                                  isCtrl: isCtrl,
                                  isShift: isShift,
                                  isAlt: isAlt,
                                );
                            setState(() => _listeningIndex = null);
                          }
                        },
                        child: Focus(
                          autofocus: true,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            // Skip bare modifier keys
                            if (event.logicalKey ==
                                    LogicalKeyboardKey.controlLeft ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.controlRight ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.shiftLeft ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.shiftRight ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.altLeft ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.altRight) {
                              return KeyEventResult.ignored;
                            }
                            final pressedKeys = HardwareKeyboard
                                .instance.logicalKeysPressed;
                            final isCtrl = pressedKeys.contains(
                                    LogicalKeyboardKey.controlLeft) ||
                                pressedKeys.contains(
                                    LogicalKeyboardKey.controlRight);
                            final isShift = pressedKeys.contains(
                                    LogicalKeyboardKey.shiftLeft) ||
                                pressedKeys.contains(
                                    LogicalKeyboardKey.shiftRight);
                            final isAlt = pressedKeys.contains(
                                    LogicalKeyboardKey.altLeft) ||
                                pressedKeys.contains(
                                    LogicalKeyboardKey.altRight);
                            ref.read(hotkeysProvider.notifier).rebind(
                                  b.action,
                                  key: event.logicalKey,
                                  type: HotkeyType.keyboard,
                                  isCtrl: isCtrl,
                                  isShift: isShift,
                                  isAlt: isAlt,
                                );
                            setState(() => _listeningIndex = null);
                            return KeyEventResult.handled;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Press key or click…',
                                style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontSize: 12)),
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () =>
                            setState(() => _listeningIndex = i),
                        child: Text(b.displayLabel,
                            style: const TextStyle(fontSize: 12)),
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(hotkeysProvider.notifier).resetAll();
            },
            child: const Text('Reset Defaults'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Instant Replay HTML video player ────────────────────────────────────

class _InstantReplayView extends StatefulWidget {
  final String replayUrl;
  const _InstantReplayView({required this.replayUrl});

  @override
  State<_InstantReplayView> createState() => _InstantReplayViewState();
}

class _InstantReplayViewState extends State<_InstantReplayView> {
  late final String _viewType;
  web.HTMLVideoElement? _video;

  @override
  void initState() {
    super.initState();
    _viewType = 'instant-replay-${widget.replayUrl.hashCode}';
    _register();
  }

  void _register() {
    final url = widget.replayUrl;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        _video = web.HTMLVideoElement()
          ..src = url
          ..controls = true
          ..autoplay = true
          ..muted = true
          ..playsInline = true
          ..preload = 'auto'
          ..loop = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000';

        return _video!;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

// ── Recording Pulse Button ──────────────────────────────────────────────

class _RecordingPulseButton extends StatefulWidget {
  final int elapsedSeconds;
  const _RecordingPulseButton({required this.elapsedSeconds});

  @override
  State<_RecordingPulseButton> createState() => _RecordingPulseButtonState();
}

class _RecordingPulseButtonState extends State<_RecordingPulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
          child: Icon(
            Icons.square,
            size: 16,
            color: Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatTime(widget.elapsedSeconds),
          style: const TextStyle(fontSize: 8),
        ),
      ],
    );
  }
}

// ── Recording Upload Dialog ────────────────────────────────────────────

class _RecordingUploadDialog extends ConsumerWidget {
  final String roomId;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _RecordingUploadDialog({
    required this.roomId,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(screenRecordingProvider);
    final isUploading = recordingState.isUploading;
    final uploadProgress = recordingState.uploadProgress;

    return PointerInterceptor(
      child: AlertDialog(
        title: const Text('Save Recording'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload your scrim recording to Firebase Storage?'),
              const SizedBox(height: 16),
              if (isUploading) ...[
                const Text('Uploading...'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 8),
                Text(
                  '${(uploadProgress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
              ] else if (recordingState.downloadUrl != null) ...[
                const Text(
                  'Recording uploaded successfully!',
                  style: TextStyle(color: Colors.green),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final url = recordingState.downloadUrl!;
                    web.window.open(url, '_blank');
                  },
                  child: Text(
                    'View Recording',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!isUploading && recordingState.downloadUrl == null)
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          if (!isUploading && recordingState.downloadUrl == null)
            ElevatedButton(
              onPressed: onConfirm,
              child: const Text('Upload'),
            ),
          if (isUploading || recordingState.downloadUrl != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(screenRecordingProvider.notifier).clearError();
              },
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}

