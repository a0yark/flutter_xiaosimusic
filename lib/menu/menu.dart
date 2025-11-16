import 'package:flutter/material.dart';
import 'FavoriteButton.dart';
import 'PlayPauseButton.dart';
import 'menu_vm.dart'; // 引入 MenuViewModel
import 'audio_provider.dart'; // 确保导入 AudioProvider
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MusicListBottomSheet extends StatefulWidget {
  final Function(String) onSongSelected; // 回调函数，用于通知主页选择的歌曲
  final MenuViewModel viewModel; // 从外部传入的 viewModel

  const MusicListBottomSheet({
    Key? key,
    required this.onSongSelected,
    required this.viewModel,
  }) : super(key: key);

  @override
  _MusicListBottomSheetState createState() => _MusicListBottomSheetState();
}

class _MusicListBottomSheetState extends State<MusicListBottomSheet> {
  bool isFavoritesView = false; // 用于控制显示当前播放列表还是收藏列表

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handleViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleViewModelChanged);
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // 新增方法：下载 krc 文件
  Future<void> downloadKrcFile(String songName) async {
    try {
      // 这里需要根据实际情况修改 krc 文件的下载链接
      String krcDownloadUrl = 'https://example.com/api/krc?song=$songName';
      final response = await http.get(Uri.parse(krcDownloadUrl));
      if (response.statusCode == 200) {
        // 获取应用文档目录
        final directory = await getApplicationDocumentsDirectory();
        final krcFile = File('${directory.path}/$songName.krc');
        await krcFile.writeAsBytes(response.bodyBytes);
        print('krc 文件下载成功: ${krcFile.path}');
      } else {
        print('krc 文件下载失败: ${response.statusCode}');
      }
    } catch (e) {
      print('下载 krc 文件时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 2 / 3,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFavoritesView ? '我的收藏' : '当前播放',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // 切换显示当前播放列表或我的收藏列表
                      setState(() {
                        isFavoritesView = !isFavoritesView;
                      });
                    },
                    child: Text(isFavoritesView ? '当前播放' : '我的收藏'),
                  ),
                  TextButton(
                    onPressed: () async {
                      // 调用 ViewModel 中的添加歌曲功能
                      await widget.viewModel.addSongFromDevice(context);
                    },
                    child: Text('添加歌曲'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: isFavoritesView
                  ? widget.viewModel.getFavorites().length
                  : widget.viewModel.getAudioFiles().length,
              itemBuilder: (context, index) {
                final filePath = isFavoritesView
                    ? widget.viewModel.getFavorites()[index]
                    : widget.viewModel.getAudioFiles()[index];
                // 提取歌曲名
                String songName = filePath.split('/').last.split('.').first;

                // 下载 krc 文件
                downloadKrcFile(songName);

                return Dismissible(
                  key: Key(filePath),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) async {
                    // 调用删除歌曲的方法
                    await widget.viewModel.deleteSong(filePath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("已删除: ${filePath.split('/').last}")),
                    );
                  },
                  child: ListTile(
                    title: Text(filePath.split('/').last), // 显示文件名
                    subtitle: Text('本地歌曲'), // 可以根据需要显示更多信息
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayPauseButton(
                          filePath: filePath,
                        ),
                        FavoriteButton(
                          filePath: filePath,
                        ),
                      ],
                    ),
                    onTap: () {
                      // 通知主页选择的歌曲
                      widget.onSongSelected(filePath);
                      Navigator.pop(context); // 关闭底部菜单
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void showMusicListBottomSheet(BuildContext context, {required Function(String) onSongSelected, required MenuViewModel viewModel}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return MusicListBottomSheet(
        onSongSelected: onSongSelected,
        viewModel: viewModel, // 传递 viewModel
      );
    },
  );
}
