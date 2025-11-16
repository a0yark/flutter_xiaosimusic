import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'NotificationHelper.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();
  String? currentFilePath;
  bool isPlaying = false;

  AudioProvider() {
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed) {
        isPlaying = state.playing;
        updateNotification();
        notifyListeners();
      }
    });

    audioPlayer.positionStream.listen((position) {
      if (position >= (audioPlayer.duration ?? Duration.zero) &&
          audioPlayer.duration != null) {
        isPlaying = false;
        updateNotification();
        notifyListeners();
        audioPlayer.seek(Duration.zero);
      }
    });
  }

  void updateNotification() {
    NotificationHelper.showNotification(
      id: 1,
      title: isPlaying ? '正在播放' : '暂停播放',
      body: currentFilePath?.split('/').last ?? '未知歌曲',
      payload: currentFilePath,
    );
  }

  Future<void> togglePlay(String filePath) async {
    try {
      if (filePath != currentFilePath) {
        await _startNewSource(filePath);
        return;
      }

      if (isPlaying) {
        await audioPlayer.pause();
        isPlaying = false;
      } else {
        await audioPlayer.play();
        isPlaying = true;
      }

      updateNotification();
      notifyListeners();
    } catch (e) {
      debugPrint('播放出错: $e');
    }
  }

  Future<void> playRandomSong(List<String> files) async {
    if (files.isEmpty) return;
    final randomSongPath = files[Random().nextInt(files.length)];
    await togglePlay(randomSongPath);
  }

  Future<void> stop() async {
    await audioPlayer.stop();
    isPlaying = false;
    currentFilePath = null;
    updateNotification();
    notifyListeners();
  }

  bool get getIsPlaying => isPlaying;

  String? get getCurrentFilePath => currentFilePath;

  Future<void> _startNewSource(String filePath) async {
    await audioPlayer.stop();
    if (filePath.startsWith('assets/')) {
      await audioPlayer.setAsset(filePath);
    } else {
      await audioPlayer.setFilePath(filePath);
    }
    currentFilePath = filePath;
    await audioPlayer.play();
    isPlaying = true;
    updateNotification();
    notifyListeners();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
