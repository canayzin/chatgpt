import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const appCategories = [
  'psikoloji',
  'finans',
  'manipulation',
  'entrepreneurship',
  'interesting_facts',
  'cognitive_biases',
  'genel_kultur_ve_merak',
];

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

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: appCategories.isEmpty
          ? const Center(child: Text('No categories available yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: appCategories.length,
              itemBuilder: (context, index) {
                final category = appCategories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/categories/$category'),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        _categoryLabel(category),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
