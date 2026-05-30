import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rov_coach/data/models/user_model.dart';
import 'package:rov_coach/providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _roomIdController = TextEditingController();

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authActionsProvider).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Failed to load profile: $error'),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile found.'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileCard(profile: profile),
                  const SizedBox(height: 16),
                  _LegacyRoomCard(
                    controller: _roomIdController,
                    onGo: (roomId) {
                      context.go('/room/$roomId/roster');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.inGameName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(profile.email),
            const SizedBox(height: 16),
            _InfoRow(label: 'Roles', value: _formatList(profile.roles)),
            _InfoRow(
              label: 'Preferred Roles',
              value: _formatList(profile.preferredRoles),
            ),
            _InfoRow(label: 'Main Heroes', value: _formatList(profile.mainHeroes)),
            _InfoRow(
              label: 'Non-Main Heroes',
              value: _formatList(profile.nonMainHeroes),
            ),
            _InfoRow(
              label: 'Current Team ID',
              value: profile.currentTeamId ?? 'None',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyRoomCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onGo;

  const _LegacyRoomCard({
    required this.controller,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legacy Room Access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                hintText: 'e.g. 3hxyf6yf',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final roomId = controller.text.trim();
                  if (roomId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a room ID.')),
                    );
                    return;
                  }
                  onGo(roomId);
                },
                child: const Text('Go to Legacy Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatList(List<String> items) {
  if (items.isEmpty) return 'None';
  return items.join(', ');
}
