import 'package:flutter/material.dart';
import 'package:rov_coach/data/hero_database.dart';

/// A reusable bottom sheet that lets the user search, filter by role, and
/// select a hero from [RoVDatabase].
///
/// Returns the selected [HeroModel] or `null` if dismissed.
///
/// [unavailableHeroes] — hero names that should be shown as disabled (already
/// picked/banned in draft, or already in a list).
///
/// [highlightedHeroes] — hero names to badge with a star (comfort / strategy
/// match during draft).
Future<HeroModel?> showHeroSelectionModal(
  BuildContext context, {
  Set<String> unavailableHeroes = const {},
  Set<String> highlightedHeroes = const {},
}) {
  return showModalBottomSheet<HeroModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HeroSelectionSheet(
      unavailableHeroes: unavailableHeroes,
      highlightedHeroes: highlightedHeroes,
    ),
  );
}

class _HeroSelectionSheet extends StatefulWidget {
  final Set<String> unavailableHeroes;
  final Set<String> highlightedHeroes;

  const _HeroSelectionSheet({
    required this.unavailableHeroes,
    required this.highlightedHeroes,
  });

  @override
  State<_HeroSelectionSheet> createState() => _HeroSelectionSheetState();
}

class _HeroSelectionSheetState extends State<_HeroSelectionSheet> {
  String _search = '';
  String? _roleFilter; // null = All

  List<HeroModel> get _filtered {
    var list = RoVDatabase.allHeroes;
    if (_roleFilter != null) {
      list = list.where((h) => h.mainRole == _roleFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((h) => h.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heroes = _filtered;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          // ── Handle bar ──
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search hero...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── Role filter chips ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _RoleChip(
                  label: 'All',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                for (final role in RoVDatabase.roles)
                  _RoleChip(
                    label: role,
                    selected: _roleFilter == role,
                    onTap: () => setState(() => _roleFilter = role),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Hero grid ──
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: heroes.length,
              itemBuilder: (context, i) {
                final hero = heroes[i];
                final unavailable =
                    widget.unavailableHeroes.contains(hero.name);
                final highlighted =
                    widget.highlightedHeroes.contains(hero.name);

                return _HeroTile(
                  hero: hero,
                  unavailable: unavailable,
                  highlighted: highlighted,
                  onTap: unavailable
                      ? null
                      : () => Navigator.of(context).pop(hero),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  final HeroModel hero;
  final bool unavailable;
  final bool highlighted;
  final VoidCallback? onTap;

  const _HeroTile({
    required this.hero,
    required this.unavailable,
    required this.highlighted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Opacity(
      opacity: unavailable ? 0.35 : 1.0,
      child: Material(
        color: highlighted
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Full-bleed hero image ──
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  hero.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      hero.name.isNotEmpty ? hero.name[0] : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Gradient + name at bottom ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Text(
                    hero.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              if (highlighted)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.star, size: 16, color: cs.primary),
                ),
              if (unavailable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.block, size: 32,
                          color: cs.error.withAlpha(180)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
