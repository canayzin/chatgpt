import 'package:flutter/material.dart';

import '../../feed/domain/knowledge_model.dart';
import '../../feed/presentation/feed_screen.dart';

String _categoryLabel(String category) {
  switch (category) {
    case 'psikoloji':
      return 'Psikoloji';
    case 'finans':
      return 'Finans';
    case 'manipulation':
      return 'Manip\u00fclasyon';
    case 'entrepreneurship':
      return 'Giri\u015fimcilik';
    case 'interesting_facts':
      return '\u0130lgin\u00e7 Bilgiler';
    case 'cognitive_biases':
      return 'Bili\u015fsel \u00d6nyarg\u0131lar';
    case 'genel_kultur_ve_merak':
      return 'Genel K\u00fclt\u00fcr ve Merak';
    default:
      return category.replaceAll('_', ' ').toUpperCase();
  }
}

class CategoryFeedScreen extends StatelessWidget {
  const CategoryFeedScreen({required this.category, super.key});

  final String category;

  @override
  Widget build(BuildContext context) {
    return FeedScreen(
      query: FeedQuery(category: category),
      title: _categoryLabel(category),
      showCategoryChip: false,
    );
  }
}
