import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  Future<void> playFromUrl(String url, {FutureOr<void> Function()? onComplete}) async {
    StreamSubscription<PlayerState>? sub;
    if (onComplete != null) {
      sub = _player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          await onComplete();
          await sub?.cancel();
        }
      });
    }

    await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    await _player.play();
  }

  Future<void> playPlaylist(List<String> urls) async {
    final playlist = ConcatenatingAudioSource(
      children: urls.map((url) => AudioSource.uri(Uri.parse(url))).toList(),
    );
    await _player.setAudioSource(playlist);
    await _player.play();
  }

  Future<void> skipToNext() => _player.seekToNext();

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> dispose() async {
    await _player.dispose();
  }
}
