import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../services/invite_link_generator.dart';
import '../services/referral_service.dart';

class InviteFriendsScreen extends ConsumerStatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  ConsumerState<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends ConsumerState<InviteFriendsScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(referralProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Friends')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load referral profile: $error')),
        data: (profile) {
          final installs = profile.successfulInstalls;
          final invites = profile.totalInvites;
          final nextMilestone = installs < 1
              ? 1
              : installs < 3
                  ? 3
                  : installs < 5
                      ? 5
                      : installs < 10
                          ? 10
                          : installs + 5;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Your referral code'),
                  subtitle: Text(profile.referralCode),
                  trailing: IconButton(
                    onPressed: () => Share.share(profile.referralCode),
                    icon: const Icon(Icons.copy),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite progress', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Invites sent: $invites'),
                      Text('Successful installs: $installs'),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: (installs / nextMilestone).clamp(0.0, 1.0)),
                      const SizedBox(height: 6),
                      Text('Next reward unlocks at $nextMilestone installs'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rewards'),
                      const SizedBox(height: 8),
                      Text('• 1 install: Bonus streak badge'),
                      Text('• 3 installs: Exclusive knowledge series'),
                      Text('• 5 installs: Extra quiz pack'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        try {
                          final code = profile.referralCode;
                          final link = await ref.read(inviteLinkGeneratorProvider).buildInviteLink(referralCode: code);
                          await ref.read(referralServiceProvider).registerInviteSent();
                          await Share.share('Join me on AI Learn: $link');
                        } finally {
                          if (mounted) setState(() => _loading = false);
                        }
                      },
                icon: const Icon(Icons.send),
                label: Text(_loading ? 'Preparing invite...' : 'Invite Friends'),
              ),
            ],
          );
        },
      ),
    );
  }
}
