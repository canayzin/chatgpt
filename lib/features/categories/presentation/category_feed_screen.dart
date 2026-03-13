import 'package:flutter/material.dart';

import '../../feed/domain/knowledge_model.dart';
import '../../feed/presentation/feed_screen.dart';

class CategoryFeedScreen extends StatelessWidget {
  const CategoryFeedScreen({required this.category, super.key});

  final String category;

  @override
  Widget build(BuildContext context) {
    return FeedScreen(
      query: FeedQuery(category: category),
      title: category.replaceAll('_', ' ').toUpperCase(),
      showCategoryChip: false,
    );
  }
}
