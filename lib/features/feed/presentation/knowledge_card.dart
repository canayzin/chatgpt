import 'package:flutter/material.dart';

import '../domain/knowledge_model.dart';

class KnowledgeCard extends StatefulWidget {
  const KnowledgeCard({
    required this.item,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onListenTap,
    required this.onMeaningfulInteraction,
    required this.onShareTap,
    this.showCategoryChip = true,
    super.key,
  });

  final KnowledgeModel item;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onListenTap;
  final VoidCallback onMeaningfulInteraction;
  final VoidCallback onShareTap;
  final bool showCategoryChip;

  @override
  State<KnowledgeCard> createState() => _KnowledgeCardState();
}

class _KnowledgeCardState extends State<KnowledgeCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.showCategoryChip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.item.category.toUpperCase(),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  if (widget.item.isDailyKnowledge)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: const Text('Daily'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${widget.item.createdAt.day}/${widget.item.createdAt.month}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.item.question,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(widget.item.shortAnswer),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _showDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(widget.item.details ?? ''),
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.item.hasAudio ? widget.onListenTap : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Listen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: (widget.item.details ?? '').isEmpty
                        ? null
                        : () {
                            setState(() => _showDetails = !_showDetails);
                            widget.onMeaningfulInteraction();
                          },
                    icon: const Icon(Icons.menu_book),
                    label: Text(_showDetails ? 'Hide details' : 'Details'),
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    onPressed: () {
                      widget.onFavoriteTap();
                      widget.onMeaningfulInteraction();
                    },
                    icon: Icon(
                      widget.isFavorite ? Icons.star : Icons.star_border,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () {
                      widget.onMeaningfulInteraction();
                      widget.onShareTap();
                    },
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
