import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MenuViewModel extends ChangeNotifier {
  List<String> audioFiles = [];
  Map<String, bool> isFavorited = {}; // 用于记录每个文件的收藏状态

  MenuViewModel() {
    _loadFavorites(); // 加载收藏状态
    _loadAudioFiles(); // 加载本地歌曲列表
    _initializeDefaultFiles(); // 初始化默认的内置音乐文件
  }

  Future<void> _initializeDefaultFiles() async {
    // 初始化默认的内置音乐文件
    final defaultFiles = [
      'assets/music/1.mp3', // 示例内置音乐文件路径
      // 可以根据需要添加更多默认文件
    ];

    // 检查是否已经加载过默认文件
    if (audioFiles.isEmpty) {
      audioFiles.addAll(defaultFiles);
      isFavorited.addEntries(defaultFiles.map((file) => MapEntry(file, false)));
      await _saveAudioFiles(); // 保存到本地文件
    }
  }

  Future<void> _loadFavorites() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/收藏.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      final favorites = contents.split(',');
      for (var filePath in favorites) {
        if (filePath.isNotEmpty) {
          isFavorited[filePath] = true;
        }
      }
    }
    notifyListeners();
  }

  Future<void> _loadAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/歌曲列表.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      audioFiles = contents.split(',');
    }
    notifyListeners();
  }

  Future<void> addSongFromDevice(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!await _ensureStoragePermission()) {
      messenger.showSnackBar(
        const SnackBar(content: Text("没有存储权限，无法添加歌曲")),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg'],
        type: FileType.custom,
        withData: false,
      );

      if (result == null || result.paths.isEmpty) {
        return;
      }

      final List<String> newFiles = [];
      for (final path in result.paths) {
        if (path == null) continue;
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        if (!audioFiles.contains(path)) {
          audioFiles.add(path);
          isFavorited[path] = false;
          newFiles.add(path);
        }
      }

      if (newFiles.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text("未选择新的歌曲")),
        );
        return;
      }

      await _saveAudioFiles(); // 保存歌曲列表
      notifyListeners();
      messenger.showSnackBar(
        SnackBar(content: Text("已添加 ${newFiles.length} 首歌曲")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("选择文件失败: $e")),
      );
    }
  }

  Future<void> _saveAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/歌曲列表.txt');
    await file.writeAsString(audioFiles.join(',')); // 保存歌曲列表
  }

  void toggleFavorite(String filePath) {
    if (!isFavorited.containsKey(filePath)) {
      isFavorited[filePath] = false;
    }
    isFavorited[filePath] = !(isFavorited[filePath] ?? false);
    _saveFavorites(); // 保存收藏状态
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/收藏.txt');
    final favorites = isFavorited.entries.where((entry) => entry.value).map((entry) => entry.key).toList();
    await file.writeAsString(favorites.join(',')); // 保存收藏状态
  }

  List<String> getAudioFiles() {
    return audioFiles;
  }

  List<String> getFavorites() {
    return audioFiles.where((file) => isFavorited[file] ?? false).toList();
  }

  bool getIsFavorited(String filePath) {
    return isFavorited[filePath] ?? false;
  }

  // 新增删除歌曲的方法
  Future<void> deleteSong(String filePath) async {
    if (filePath.startsWith('assets/music/1.mp3')) {
      // 如果是内置歌曲，不进行删除操作
      _showToast("内置歌曲不能删除哦");
      return;
    }
    // 从 audioFiles 列表中移除歌曲
    audioFiles.remove(filePath);
    // 从收藏状态中移除该歌曲的记录
    isFavorited.remove(filePath);
    // 更新本地歌曲列表文件
    await _saveAudioFiles();
    // 更新本地收藏文件
    await _saveFavorites();
    notifyListeners();
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      return true;
    }

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) {
      return true;
    }

    final manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }
}

void _showToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.black87,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
