import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/player.dart';
import 'package:rov_coach/providers/roster_provider.dart';
import 'package:rov_coach/presentation/widgets/hero_selection_modal.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';

const _uuid = Uuid();

/// Full-screen form for adding or editing a [Player].
/// Pass an existing [player] to edit, or `null` to add a new one.
class PlayerFormScreen extends ConsumerStatefulWidget {
  final Player? player;

  const PlayerFormScreen({super.key, this.player});

  @override
  ConsumerState<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends ConsumerState<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ignController;
  late PlayerRole _selectedRole;
  late String _status;
  late List<String> _comfortPicks;
  late List<String> _weakPicks;

  bool get _isEditing => widget.player != null;

  @override
  void initState() {
    super.initState();
    _ignController = TextEditingController(text: widget.player?.ign ?? '');
    _selectedRole = widget.player?.mainRole ?? PlayerRole.slayerLane;
    _status = widget.player?.status ?? 'Active';
    _comfortPicks = List.from(widget.player?.comfortPicks ?? []);
    _weakPicks = List.from(widget.player?.weakPicks ?? []);
  }

  @override
  void dispose() {
    _ignController.dispose();
    super.dispose();
  }

  Future<void> _addHeroTo(List<String> pool) async {
    final alreadyUsed = {..._comfortPicks, ..._weakPicks};
    final hero = await showHeroSelectionModal(
      context,
      unavailableHeroes: alreadyUsed,
    );
    if (hero != null && mounted) {
      setState(() => pool.add(hero.name));
    }
  }

  void _removeHeroFrom(List<String> pool, String name) {
    setState(() => pool.remove(name));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final player = Player(
      id: widget.player?.id ?? _uuid.v4(),
      ign: _ignController.text.trim(),
      mainRole: _selectedRole,
      name: _ignController.text.trim(),
      role: _selectedRole.label,
      status: _status,
      comfortPicks: _comfortPicks,
      weakPicks: _weakPicks,
    );

    if (_isEditing) {
      await ref.read(rosterActionsProvider).updatePlayer(player);
    } else {
      await ref.read(rosterActionsProvider).addPlayer(player);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Player'),
        content: Text('Remove ${widget.player!.ign} from the roster?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(rosterActionsProvider).removePlayer(widget.player!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Player' : 'Add Player'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── IGN ──
            TextFormField(
              controller: _ignController,
              decoration: const InputDecoration(
                labelText: 'In-Game Name (IGN)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),

            // ── Main Role ──
            DropdownButtonFormField<PlayerRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Main Role',
                border: OutlineInputBorder(),
              ),
              items: PlayerRole.values
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedRole = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Benched', child: Text('Benched')),
                DropdownMenuItem(value: 'On Fire', child: Text('On Fire')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 24),

            // ── Comfort Picks ──
            _HeroPoolSection(
              title: 'Comfort Picks (Mastered)',
              heroes: _comfortPicks,
              color: Colors.green,
              onAdd: () => _addHeroTo(_comfortPicks),
              onRemove: (name) => _removeHeroFrom(_comfortPicks, name),
            ),
            const SizedBox(height: 16),

            // ── Weak Picks ──
            _HeroPoolSection(
              title: 'Weak Picks (Needs Practice)',
              heroes: _weakPicks,
              color: Colors.orange,
              onAdd: () => _addHeroTo(_weakPicks),
              onRemove: (name) => _removeHeroFrom(_weakPicks, name),
            ),
            const SizedBox(height: 32),

            // ── Save ──
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Player' : 'Add Player'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a labeled section of hero chips with an Add button.
class _HeroPoolSection extends StatelessWidget {
  final String title;
  final List<String> heroes;
  final Color color;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _HeroPoolSection({
    required this.title,
    required this.heroes,
    required this.color,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (heroes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No heroes selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: heroes
                .map((name) => Chip(
                      avatar: HeroAvatar.fromName(name, size: 24),
                      label: Text(name),
                      backgroundColor: color.withAlpha(40),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => onRemove(name),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
