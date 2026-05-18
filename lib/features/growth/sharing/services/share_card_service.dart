import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../feed/domain/knowledge_model.dart';

final shareCardServiceProvider = Provider<ShareCardService>((ref) {
  return ShareCardService();
});

class ShareCardService {
  static const _storySize = Size(1080, 1920);

  Future<void> shareKnowledgeCard(KnowledgeModel item) async {
    final pngBytes = await _buildKnowledgeCardImage(item);
    await Share.shareXFiles(
      [
        XFile.fromData(
          pngBytes,
          name: 'ai_learn_${item.id}.png',
          mimeType: 'image/png',
        ),
      ],
      text: 'Today I learned on AI Learn',
      subject: item.category,
    );
  }

  Future<void> shareStreak({required int streakCount}) async {
    final pngBytes = await _buildTextAchievementImage(
      title: '🔥 $streakCount day learning streak',
      subtitle: 'Consistency compounds. Keep learning with AI Learn.',
    );

    await Share.shareXFiles(
      [
        XFile.fromData(
          pngBytes,
          name: 'ai_learn_streak.png',
          mimeType: 'image/png',
        ),
      ],
      text: 'I am on a $streakCount-day AI Learn streak!',
    );
  }

  Future<void> shareQuizResult({required String topic, required int score, required int total}) async {
    final pngBytes = await _buildTextAchievementImage(
      title: '🧠 I scored $score/$total',
      subtitle: '$topic Quiz • AI Learn',
    );

    await Share.shareXFiles(
      [
        XFile.fromData(
          pngBytes,
          name: 'ai_learn_quiz_result.png',
          mimeType: 'image/png',
        ),
      ],
      text: 'I scored $score/$total in the $topic quiz on AI Learn.',
    );
  }

  Future<Uint8List> _buildKnowledgeCardImage(KnowledgeModel item) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & _storySize;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1C1E5A), Color(0xFF3A0CA3), Color(0xFF4361EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(72, 220, _storySize.width - 144, _storySize.height - 440),
      const Radius.circular(42),
    );

    canvas.drawRRect(
      cardRect,
      Paint()..color = Colors.white.withOpacity(0.95),
    );

    _paintText(
      canvas,
      text: item.category.toUpperCase(),
      maxWidth: cardRect.outerRect.width - 80,
      offset: Offset(cardRect.left + 40, cardRect.top + 40),
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF3A0CA3)),
    );

    _paintText(
      canvas,
      text: item.question,
      maxWidth: cardRect.outerRect.width - 80,
      offset: Offset(cardRect.left + 40, cardRect.top + 120),
      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.1),
    );

    _paintText(
      canvas,
      text: item.shortAnswer,
      maxWidth: cardRect.outerRect.width - 80,
      offset: Offset(cardRect.left + 40, cardRect.top + 520),
      style: const TextStyle(fontSize: 40, color: Color(0xFF334155), height: 1.3),
    );

    _paintText(
      canvas,
      text: 'AI Learn',
      maxWidth: cardRect.outerRect.width - 80,
      offset: Offset(cardRect.left + 40, cardRect.bottom - 100),
      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
    );

    final image = await recorder.endRecording().toImage(_storySize.width.toInt(), _storySize.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _buildTextAchievementImage({required String title, required String subtitle}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & _storySize;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF5400), Color(0xFFFF0054), Color(0xFF7209B7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    _paintText(
      canvas,
      text: title,
      maxWidth: _storySize.width - 180,
      offset: const Offset(90, 760),
      style: const TextStyle(fontSize: 72, color: Colors.white, fontWeight: FontWeight.w800, height: 1.1),
    );

    _paintText(
      canvas,
      text: subtitle,
      maxWidth: _storySize.width - 180,
      offset: const Offset(90, 1010),
      style: const TextStyle(fontSize: 42, color: Colors.white, height: 1.3),
    );

    _paintText(
      canvas,
      text: 'AI Learn',
      maxWidth: _storySize.width - 180,
      offset: const Offset(90, 1740),
      style: const TextStyle(fontSize: 34, color: Colors.white70, fontWeight: FontWeight.w700),
    );

    final image = await recorder.endRecording().toImage(_storySize.width.toInt(), _storySize.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required Offset offset,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 8,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    textPainter.paint(canvas, offset);
  }
}
