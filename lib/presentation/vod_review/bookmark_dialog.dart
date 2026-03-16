import 'package:flutter/material.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Preset colors the user can pick for a bookmark.
const List<Color> bookmarkColors = [
  Color(0xFFE74C3C), // Red
  Color(0xFF3498DB), // Blue
  Color(0xFF2ECC71), // Green
  Color(0xFFF39C12), // Orange
  Color(0xFF9B59B6), // Purple
  Color(0xFF1ABC9C), // Teal
];

/// Shows a dialog to add or edit a [VodBookmark].
///
/// Returns the resulting bookmark, or `null` if the user cancels.
Future<VodBookmark?> showBookmarkDialog(
  BuildContext context, {
  VodBookmark? existing,
}) {
  return showDialog<VodBookmark>(
    context: context,
    builder: (_) => _BookmarkFormDialog(existing: existing),
  );
}

class _BookmarkFormDialog extends StatefulWidget {
  final VodBookmark? existing;
  const _BookmarkFormDialog({this.existing});

  @override
  State<_BookmarkFormDialog> createState() => _BookmarkFormDialogState();
}

class _BookmarkFormDialogState extends State<_BookmarkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _notesCtrl;
  late int _selectedColor;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.existing?.url ?? '');
    _topicCtrl = TextEditingController(text: widget.existing?.topic ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _selectedColor =
        widget.existing?.colorValue ?? bookmarkColors.first.toARGB32();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _topicCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final bookmark = VodBookmark(
      id: widget.existing?.id ?? _uuid.v4(),
      url: _urlCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      colorValue: _selectedColor,
    );
    Navigator.of(context).pop(bookmark);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Bookmark' : 'Add Bookmark'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Twitch VOD URL',
                  hintText: 'https://www.twitch.tv/videos/...',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _topicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  hintText: 'e.g. Game 3 vs BACON',
                  prefixIcon: Icon(Icons.topic),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Key moments, timecodes...',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Color picker
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: bookmarkColors.map((c) {
                  final isSelected = c.toARGB32() == _selectedColor;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = c.toARGB32()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: c.withAlpha(160),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
