import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rov_coach/data/models/hall_of_fame.dart';
import 'package:rov_coach/providers/hall_of_fame_provider.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:uuid/uuid.dart';

class HallOfFameScreen extends ConsumerWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final entriesAsync = ref.watch(firestoreHallOfFameProvider);
    final roomId = ref.watch(roomIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall of Fame / Shame'),
        actions: [
          if (roomId != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Entry',
              onPressed: () => _showAddDialog(context, ref, roomId),
            ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64, color: cs.primary.withAlpha(120)),
                  const SizedBox(height: 16),
                  Text('No entries yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add your first Hall of Fame or Shame card!',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return LayoutBuilder(builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 500
                    ? 2
                    : 1;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) =>
                  _HallCard(entry: entries[i], roomId: roomId),
            );
          });
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String roomId) {
    showDialog(
      context: context,
      builder: (ctx) => _EntryDialog(roomId: roomId),
    );
  }
}

// ── Hall Card ───────────────────────────────────────────────────────────

class _HallCard extends ConsumerWidget {
  final HallEntry entry;
  final String? roomId;
  const _HallCard({required this.entry, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isFame = entry.tag == HallTag.fame;
    final glowColor = isFame
        ? const Color(0xFFFFD700) // gold
        : const Color(0xFFFF4444); // red

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor.withAlpha(80),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: glowColor.withAlpha(120), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
            Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isFame ? Icons.emoji_events : Icons.thumb_down,
                      color: glowColor,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: glowColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: glowColor.withAlpha(80)),
                      ),
                      child: Text(
                        isFame ? 'FAME' : 'SHAME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: glowColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        entry.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: const Center(
                              child: Icon(Icons.broken_image, size: 32)),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: glowColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          isFame ? Icons.emoji_events : Icons.thumb_down,
                          size: 48,
                          color: glowColor.withAlpha(60),
                        ),
                      ),
                    ),
                  ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Emoji floating on top-right corner
          if (entry.emoji != null && entry.emoji!.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.emoji!,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          // Edit / Delete buttons
          if (roomId != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CardAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _EntryDialog(
                        roomId: roomId!,
                        existing: entry,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _CardAction(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: Colors.red,
                    onTap: () => _confirmDelete(context, ref, roomId!),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String roomId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Remove "${entry.title}" from the Hall?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              ref
                  .read(hallOfFameRepositoryProvider)
                  .removeEntry(roomId, entry.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  const _CardAction({required this.icon, required this.tooltip, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? Colors.white),
        ),
      ),
    );
  }
}

// ── Add Entry Dialog ────────────────────────────────────────────────────

class _EntryDialog extends ConsumerStatefulWidget {
  final String roomId;
  final HallEntry? existing;
  const _EntryDialog({required this.roomId, this.existing});

  @override
  ConsumerState<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<_EntryDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late HallTag _tag;
  String? _selectedEmoji;
  Uint8List? _imageBytes;
  String? _existingImageUrl;
  bool _uploading = false;

  bool get _isEdit => widget.existing != null;

  static const _emojis = ['👑', '🤡', '🔥', '💀', '👽', '🏆', '💎', '😈', '⚡', '🎯'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _tag = e?.tag ?? HallTag.fame;
    _selectedEmoji = e?.emoji;
    _existingImageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _existingImageUrl = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (_uploading) return;

    setState(() => _uploading = true);

    // Convert image to base64 data URL (avoids Firebase Storage dependency)
    String? imageUrl = _existingImageUrl;
    if (_imageBytes != null) {
      final b64 = base64Encode(_imageBytes!);
      imageUrl = 'data:image/jpeg;base64,$b64';
    }

    final entryId = widget.existing?.id ?? const Uuid().v4();
    final entry = HallEntry(
      id: entryId,
      title: title,
      description: _descCtrl.text.trim(),
      tag: _tag,
      imageUrl: imageUrl,
      emoji: _selectedEmoji,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    final repo = ref.read(hallOfFameRepositoryProvider);
    if (_isEdit) {
      repo.updateEntry(widget.roomId, entry);
    } else {
      repo.addEntry(widget.roomId, entry);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Hall Entry' : 'Add Hall Entry'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<HallTag>(
                segments: const [
                  ButtonSegment(
                    value: HallTag.fame,
                    label: Text('Fame'),
                    icon: Icon(Icons.emoji_events),
                  ),
                  ButtonSegment(
                    value: HallTag.shame,
                    label: Text('Shame'),
                    icon: Icon(Icons.thumb_down),
                  ),
                ],
                selected: {_tag},
                onSelectionChanged: (v) => setState(() => _tag = v.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Perfect Dragon Steal',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // ── Emoji selector ──
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Pick Emoji (optional)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _emojis.map((e) {
                  final selected = _selectedEmoji == e;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedEmoji = selected ? null : e;
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? cs.primary
                              : cs.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // ── Image picker ──
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _imageBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close, size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => setState(() {
                          _imageBytes = null;
                        }),
                      ),
                    ),
                  ],
                )
              else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _existingImageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close, size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => setState(() {
                          _existingImageUrl = null;
                        }),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Pick Image'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
