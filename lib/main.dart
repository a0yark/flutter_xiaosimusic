// 导入Flutter核心UI库，提供Material Design风格的组件
import 'package:flutter/material.dart';
// 导入Provider状态管理库，用于管理应用状态
import 'package:provider/provider.dart';
// 导入主页面组件，显示音乐播放界面
import 'package:xiaosimusic/song_page.dart';
// 导入应用模型类，管理全局应用状态（如收藏状态）
import 'package:xiaosimusic/app_model.dart'; // 确保导入 AppModel
// 导入菜单视图模型类，管理音乐文件列表和菜单操作
import 'package:xiaosimusic/menu/menu_vm.dart'; // 确保导入 MenuViewModel
// 导入音频提供者类，管理音频播放控制和状态
import 'package:xiaosimusic/menu/audio_provider.dart'; // 确保导入 AudioProvider
// 导入通知帮助类，用于显示系统通知
//import 'package:xiaosimusic/menu/NotificationHelper.dart'; // 导入通知服务

// 应用程序入口函数
void main() async {
  // 确保Flutter绑定已初始化，在使用插件前必须调用
  WidgetsFlutterBinding.ensureInitialized();

  // 启动Flutter应用
  runApp(
    // MultiProvider允许同时管理多个状态提供者
    MultiProvider(
      // 定义所有状态提供者列表
      providers: [
        // 创建AppModel实例，管理应用全局状态（如收藏状态）
        // create参数使用函数创建实例，确保每次访问时使用同一个实例
        ChangeNotifierProvider(create: (_) => AppModel()), // 管理 AppModel
        // 创建MenuViewModel实例，管理音乐文件列表和菜单操作
        ChangeNotifierProvider(create: (_) => MenuViewModel()), // 管理 MenuViewModel
        // 创建AudioProvider实例，管理音频播放控制和状态
        ChangeNotifierProvider(create: (_) => AudioProvider()), // 管理 AudioProvider
      ],
      // 将所有提供者包装在MyApp根组件中
      child: const MyApp(),
    ),
  );
}

// 应用程序的根组件
class MyApp extends StatelessWidget {
  // 构造函数，key用于标识组件
  const MyApp({super.key});

  // 构建UI的方法
  @override
  Widget build(BuildContext context) {
    // 返回MaterialApp组件，配置应用的基本设置
    return MaterialApp(
      // 禁用调试横幅，在右上角显示的"DEBUG"标签
      debugShowCheckedModeBanner: false,
      // 设置应用的起始页面为SongPage组件
      home: SongPage(),
    );
  }
}
