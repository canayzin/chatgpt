import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content_draft_model.dart';
import 'admin_content_controller.dart';

class AdminContentDashboardScreen extends ConsumerStatefulWidget {
  const AdminContentDashboardScreen({super.key});

  @override
  ConsumerState<AdminContentDashboardScreen> createState() => _AdminContentDashboardScreenState();
}

class _AdminContentDashboardScreenState extends ConsumerState<AdminContentDashboardScreen> {
  ModerationStatus _selected = ModerationStatus.pending;

  static const _categories = [
    'psychology',
    'finance',
    'manipulation techniques',
    'entrepreneurship',
    'cognitive biases',
    'interesting facts',
  ];

  @override
  Widget build(BuildContext context) {
    final draftsAsync = ref.watch(moderationQueueProvider(_selected));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Content Studio'),
        actions: [
          IconButton(
            onPressed: _showGenerateDialog,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate batch',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ModerationStatus>(
              segments: ModerationStatus.values
                  .map((status) => ButtonSegment(value: status, label: Text(status.name)))
                  .toList(),
              selected: {_selected},
              onSelectionChanged: (next) => setState(() => _selected = next.first),
            ),
          ),
          Expanded(
            child: draftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load queue: $error')),
              data: (drafts) {
                if (drafts.isEmpty) {
                  return const Center(child: Text('No items in this queue.'));
                }

                return ListView.separated(
                  itemCount: drafts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return ListTile(
                      title: Text(draft.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${draft.category} • tags: ${draft.tags.join(', ')}', maxLines: 2),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _onActionSelected(action, draft),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'preview', child: Text('Preview/Edit')),
                          PopupMenuItem(value: 'approve', child: Text('Approve')),
                          PopupMenuItem(value: 'reject', child: Text('Reject')),
                          PopupMenuItem(value: 'audio', child: Text('Generate audio')),
                          PopupMenuItem(value: 'publish', child: Text('Publish')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onActionSelected(String action, ContentDraftModel draft) async {
    final controller = ref.read(adminContentControllerProvider);
    switch (action) {
      case 'preview':
        await _showEditSheet(draft);
        break;
      case 'approve':
        await controller.approveDraft(draft.id);
        break;
      case 'reject':
        await controller.rejectDraft(draft.id, note: 'Rejected by editor');
        break;
      case 'audio':
        await controller.generateAudio(draft);
        break;
      case 'publish':
        await controller.publishDraft(draft);
        break;
      default:
        break;
    }
  }

  Future<void> _showGenerateDialog() async {
    final controller = ref.read(adminContentControllerProvider);
    final countController = TextEditingController(text: '60');
    final selected = <String>{..._categories.take(3)};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Generate AI batch'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total items (50-200)'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            selected: selected.contains(category),
                            label: Text(category),
                            onSelected: (isSelected) {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.add(category);
                                } else {
                                  selected.remove(category);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final totalItems = int.tryParse(countController.text) ?? 60;
    final batchId = await controller.generateBatch(
      totalItems: totalItems.clamp(50, 200),
      categories: selected.isEmpty ? _categories : selected.toList(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch queued: $batchId')));
  }

  Future<void> _showEditSheet(ContentDraftModel draft) async {
    final questionController = TextEditingController(text: draft.question);
    final answerController = TextEditingController(text: draft.shortAnswer);
    final detailsController = TextEditingController(text: draft.detailExplanation);
    final tagsController = TextEditingController(text: draft.tags.join(', '));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: questionController, decoration: const InputDecoration(labelText: 'Question')),
                TextField(controller: answerController, decoration: const InputDecoration(labelText: 'Short answer')),
                TextField(
                  controller: detailsController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Detailed explanation'),
                ),
                TextField(controller: tagsController, decoration: const InputDecoration(labelText: 'Tags (comma)')),
                const SizedBox(height: 12),
                _PreviewCard(
                  category: draft.category,
                  question: questionController.text,
                  answer: answerController.text,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final updated = draft.copyWith(
                      question: questionController.text.trim(),
                      shortAnswer: answerController.text.trim(),
                      detailExplanation: detailsController.text.trim(),
                      tags: tagsController.text
                          .split(',')
                          .map((tag) => tag.trim().toLowerCase())
                          .where((tag) => tag.isNotEmpty)
                          .toList(),
                    );
                    await ref.read(adminContentControllerProvider).saveDraft(updated);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.category, required this.question, required this.answer});

  final String category;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(category.toUpperCase())),
            const SizedBox(height: 8),
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(answer),
            const SizedBox(height: 8),
            Text('AI Learn', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
