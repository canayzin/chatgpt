import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sharing/services/share_card_service.dart';
import '../../../analytics/services/analytics_event_service.dart';
import '../../../recommendation/services/interaction_tracking_service.dart';
import '../data/quiz_repository.dart';
import '../domain/quiz_models.dart';

final quizTopicProvider = StateProvider.autoDispose<String>((ref) => 'psychology');

final quizQuestionsProvider = FutureProvider.autoDispose<List<QuizQuestion>>((ref) async {
  final topic = ref.watch(quizTopicProvider);
  return ref.watch(quizRepositoryProvider).getQuiz(topic: topic);
});

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({required this.topic, super.key});

  final String topic;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _recordedResult = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(quizTopicProvider.notifier).state = widget.topic;
      ref.read(analyticsEventServiceProvider).logEvent(
            eventType: 'quiz_start',
            category: widget.topic,
            dedupeKey: 'quiz_start:${widget.topic}',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(quizQuestionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.topic.toUpperCase()} Quiz')),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Quiz unavailable: $error')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Quiz content is missing for this topic. Please try another category.'),
              ),
            );
          }

          if (_index >= questions.length) {
            if (!_recordedResult) {
              _recordedResult = true;
              Future.microtask(() async {
                await ref.read(interactionTrackingServiceProvider).trackQuizCompletion(
                      topic: widget.topic,
                      correct: _correct,
                      total: questions.length,
                    );
                await ref.read(analyticsEventServiceProvider).logEvent(
                      eventType: 'quiz_complete',
                      category: widget.topic,
                      properties: {'correct': _correct, 'total': questions.length},
                      dedupeKey: 'quiz_complete:${widget.topic}:${questions.length}',
                    );
              });
            }

            return _ResultView(
              result: QuizResult(total: questions.length, correct: _correct),
              topic: widget.topic,
              onShare: () async {
                await ref
                    .read(shareCardServiceProvider)
                    .shareQuizResult(topic: widget.topic, score: _correct, total: questions.length);
                await ref.read(analyticsEventServiceProvider).logEvent(
                      eventType: 'share_action',
                      category: widget.topic,
                      properties: {'shareType': 'quiz_result'},
                    );
              },
            );
          }

          final question = questions[_index];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question ${_index + 1} / ${questions.length}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(question.question, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      text: question.options[i],
                      isSelected: _selected == i,
                      isCorrect: _selected != null && i == question.correctIndex,
                      reveal: _selected != null,
                      onTap: _selected != null
                          ? null
                          : () {
                              setState(() {
                                _selected = i;
                                if (i == question.correctIndex) {
                                  _correct++;
                                }
                              });
                            },
                    ),
                  ),
                const Spacer(),
                if (_selected != null && (question.explanation ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(question.explanation!),
                  ),
                FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          setState(() {
                            _index++;
                            _selected = null;
                          });
                        },
                  child: Text(_index == questions.length - 1 ? 'Finish Quiz' : 'Next'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.reveal,
    this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool reveal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !reveal
        ? null
        : isCorrect
            ? Colors.green.withOpacity(0.2)
            : isSelected
                ? Colors.red.withOpacity(0.2)
                : null;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(text),
        onTap: onTap,
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onShare, required this.topic});

  final QuizResult result;
  final Future<void> Function() onShare;
  final String topic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score ${result.correct}/${result.total}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('Topic: ${topic.toUpperCase()}'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async => onShare(),
              icon: const Icon(Icons.share),
              label: const Text('Share result'),
            ),
          ],
        ),
      ),
    );
  }
}
