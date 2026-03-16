import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/strategy.dart';
import 'package:rov_coach/providers/strategy_provider.dart';
import 'package:rov_coach/presentation/widgets/hero_selection_modal.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';

const _uuid = Uuid();

/// Full-screen form for adding or editing a [Strategy].
class StrategyFormScreen extends ConsumerStatefulWidget {
  final Strategy? strategy;
  final String? initialName;
  final Map<PlayerRole, String?>? initialComposition;

  const StrategyFormScreen({
    super.key,
    this.strategy,
    this.initialName,
    this.initialComposition,
  });

  @override
  ConsumerState<StrategyFormScreen> createState() => _StrategyFormScreenState();
}

class _StrategyFormScreenState extends ConsumerState<StrategyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _earlyCtrl;
  late final TextEditingController _midLateCtrl;
  late final TextEditingController _winCondCtrl;

  // The 5 composition slots keyed by role
  late Map<PlayerRole, String?> _composition;

  bool get _isEditing => widget.strategy != null;

  @override
  void initState() {
    super.initState();
    final s = widget.strategy;
    _nameCtrl = TextEditingController(text: s?.name ?? widget.initialName ?? '');
    _earlyCtrl =
        TextEditingController(text: s?.executionGuide.earlyGamePlan ?? '');
    _midLateCtrl =
        TextEditingController(text: s?.executionGuide.midLateGamePlan ?? '');
    _winCondCtrl =
        TextEditingController(text: s?.executionGuide.keyWinConditions ?? '');

    _composition = widget.initialComposition != null
        ? Map<PlayerRole, String?>.from(widget.initialComposition!)
        : {
            PlayerRole.slayerLane: s?.composition.slayerLane,
            PlayerRole.jungle: s?.composition.jungle,
            PlayerRole.midLane: s?.composition.midLane,
            PlayerRole.abyssalDragonLane: s?.composition.abyssalDragonLane,
            PlayerRole.support: s?.composition.support,
          };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _earlyCtrl.dispose();
    _midLateCtrl.dispose();
    _winCondCtrl.dispose();
    super.dispose();
  }

  Set<String> get _pickedHeroes =>
      _composition.values.whereType<String>().toSet();

  Future<void> _pickHeroForRole(PlayerRole role) async {
    final hero = await showHeroSelectionModal(
      context,
      unavailableHeroes: _pickedHeroes,
    );
    if (hero != null && mounted) {
      setState(() => _composition[role] = hero.name);
    }
  }

  bool get _compositionComplete =>
      _composition.values.every((v) => v != null && v.isNotEmpty);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_compositionComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hero for every role.')),
      );
      return;
    }

    final strategy = Strategy(
      id: widget.strategy?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      composition: DraftComposition(
        slayerLane: _composition[PlayerRole.slayerLane]!,
        jungle: _composition[PlayerRole.jungle]!,
        midLane: _composition[PlayerRole.midLane]!,
        abyssalDragonLane: _composition[PlayerRole.abyssalDragonLane]!,
        support: _composition[PlayerRole.support]!,
      ),
      executionGuide: ExecutionGuide(
        earlyGamePlan: _earlyCtrl.text.trim(),
        midLateGamePlan: _midLateCtrl.text.trim(),
        keyWinConditions: _winCondCtrl.text.trim(),
      ),
    );

    if (_isEditing) {
      await ref.read(strategyListProvider.notifier).updateStrategy(strategy);
    } else {
      await ref.read(strategyListProvider.notifier).addStrategy(strategy);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Strategy'),
        content: Text('Remove "${widget.strategy!.name}"?'),
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
      await ref
          .read(strategyListProvider.notifier)
          .removeStrategy(widget.strategy!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Strategy' : 'New Strategy'),
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
            // ── Name ──
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Strategy Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 20),

            // ── Draft Composition ──
            Text('Draft Composition',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...PlayerRole.values.map((role) => _CompositionSlot(
                  role: role,
                  heroName: _composition[role],
                  onTap: () => _pickHeroForRole(role),
                  onClear: () =>
                      setState(() => _composition[role] = null),
                )),
            const SizedBox(height: 20),

            // ── Execution Guide ──
            Text('Execution Guide',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _earlyCtrl,
              decoration: const InputDecoration(
                labelText: 'Early Game Plan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _midLateCtrl,
              decoration: const InputDecoration(
                labelText: 'Mid / Late Game Plan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _winCondCtrl,
              decoration: const InputDecoration(
                labelText: 'Key Win Conditions',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // ── Save ──
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Strategy' : 'Create Strategy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositionSlot extends StatelessWidget {
  final PlayerRole role;
  final String? heroName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _CompositionSlot({
    required this.role,
    required this.heroName,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = heroName != null;

    return Card(
      color: filled ? cs.primaryContainer : null,
      child: ListTile(
        leading: filled
            ? HeroAvatar.fromName(heroName!, size: 40)
            : CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Text(
                  role.label.substring(0, 1),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
        title: Text(role.label),
        subtitle: Text(heroName ?? 'Tap to select'),
        trailing: filled
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
              )
            : const Icon(Icons.add_circle_outline),
        onTap: onTap,
      ),
    );
  }
}
