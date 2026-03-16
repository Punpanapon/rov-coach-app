import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/hero_database.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';

/// A collapsible side panel that shows hero avatars grouped by role.
/// Heroes can be dragged onto the VOD review board.
class HeroDragPanel extends ConsumerStatefulWidget {
  const HeroDragPanel({super.key});

  @override
  ConsumerState<HeroDragPanel> createState() => _HeroDragPanelState();
}

class _HeroDragPanelState extends ConsumerState<HeroDragPanel> {
  String _selectedRole = 'All';
  String _searchQuery = '';

  static const _roles = ['All', 'Slayer', 'Jungle', 'Mid', 'Dragon', 'Support'];

  List<HeroModel> get _filteredHeroes {
    var heroes = RoVDatabase.allHeroes;
    if (_selectedRole != 'All') {
      heroes = heroes.where((h) => h.mainRole == _selectedRole).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      heroes = heroes.where((h) => h.name.toLowerCase().contains(q)).toList();
    }
    return heroes;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(heroPanelExpandedProvider);
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: expanded ? 220 : 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(230),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Toggle button
          InkWell(
            onTap: () => ref.read(heroPanelExpandedProvider.notifier).toggle(),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                expanded ? Icons.chevron_left : Icons.chevron_right,
                color: cs.onSurface,
              ),
            ),
          ),
          if (expanded) ...[
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: SizedBox(
                height: 32,
                child: TextField(
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search hero…',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            // Role filter chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: _roles.map((role) {
                  final selected = role == _selectedRole;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(role, style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedRole = role),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            // Hero grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _filteredHeroes.length,
                itemBuilder: (context, index) {
                  final hero = _filteredHeroes[index];
                  return Draggable<HeroModel>(
                    data: hero,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _HeroTile(hero: hero, size: 48),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _HeroTile(hero: hero, size: 44),
                    ),
                    child: Tooltip(
                      message: hero.name,
                      child: _HeroTile(hero: hero, size: 44),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  final HeroModel hero;
  final double size;

  const _HeroTile({required this.hero, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        hero.imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade800,
          alignment: Alignment.center,
          child: Text(
            hero.name[0],
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
