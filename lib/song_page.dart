import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'LyricParser.dart';
import 'menu/FavoriteButton.dart';
import 'menu/menu.dart';
import 'menu/menu_vm.dart';
import 'neu_box.dart';
import 'menu/NotificationHelper.dart';
import 'menu/audio_provider.dart';
import 'AboutPage.dart';
import 'package:http/http.dart' as http;

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> with TickerProviderStateMixin {
  int currentSongIndex = 0; // 褰撳墠鎾斁姝屾洸鐨勭储寮?
  bool isSingleLoop = false; // 鍗曟洸寰幆鐘舵€?
  bool isPlayEnd = false;
  bool isShuffle = false;
  final PageController _pageController = PageController(); // 鐢ㄤ簬鎺у埗 PageView 鐨勯〉闈㈠垏鎹?
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  List<Map<String, dynamic>> lyrics = [];
  int currentLyricIndex = 0;
  String singerName = "Luo Tian Yi"; // 鍒濆鍖栨瓕鎵嬪悕瀛?
  String coverImageUrl = 'lib/images/cover_art.jpg'; // 榛樿灏侀潰鍥剧墖
  String? _lastSongPath;

  @override
  void initState() {
    super.initState();
    // 璁剧疆 NotificationHelper 鐨?BuildContext
    NotificationHelper.setContext(context);
    // 鍒濆鍖栭€氱煡
    NotificationHelper.initialize();

    // 鍒濆鍖栨棆杞姩鐢绘帶鍒跺櫒
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.1415926).animate(_rotationController);

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    _lastSongPath = audioProvider.getCurrentFilePath;
    if (_lastSongPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshSongMetadata(_lastSongPath!);
      });
    }
    // 鐩戝惉鎾斁杩涘害
    audioProvider.audioPlayer.positionStream.listen((position) {
      if (position >= (audioProvider.audioPlayer.duration ?? Duration.zero) && isPlayEnd) {
        if (isSingleLoop) {
          playCurrentSong();
        } else {
          nextSong();
        }
        isPlayEnd = false;
      }
      if (position == Duration.zero) {
        isPlayEnd = true;
      }
      updateCurrentLyricIndex(position.inMilliseconds);
    });

    // 鐩戝惉鎾斁鐘舵€佸彉鍖?
    audioProvider.addListener(() {
      if (audioProvider.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
      _handleNowPlayingChange(audioProvider);
    });

    // 鍒濆鍖栨椂鑾峰彇姝屾墜鍚嶅瓧鍜屽皝闈㈠浘鐗?
    _fetchSingerName();
    _fetchSongCoverImage();
  }

  @override
  void dispose() {
    _pageController.dispose(); // 閲婃斁 PageController 璧勬簮
    _rotationController.dispose(); // 閲婃斁鍔ㄧ敾鎺у埗鍣ㄨ祫婧?
    super.dispose();
  }

  // 鍒囨崲鍒颁笂涓€棣栨瓕
  void previousSong() {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
    final audioFiles = menuViewModel.getAudioFiles();
    if (audioFiles.isNotEmpty) {
      setState(() {
        currentSongIndex = (currentSongIndex - 1) % audioFiles.length;
        if (currentSongIndex < 0) {
          currentSongIndex = audioFiles.length - 1;
        }
      });
      playCurrentSong();
    }
  }

  // 鍒囨崲鍒颁笅涓€棣栨瓕
  void nextSong() {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
    final audioFiles = menuViewModel.getAudioFiles();
    if (audioFiles.isNotEmpty) {
      setState(() {
        currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
      });
      playCurrentSong();
    }
  }

  // 播放当前歌曲
  Future<void> playCurrentSong() async {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
    final audioFiles = menuViewModel.getAudioFiles();
    if (audioFiles.isNotEmpty) {
      final currentSongPath = audioFiles[currentSongIndex];
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await audioProvider.togglePlay(currentSongPath);
      updateNotification(currentSongPath);
      _lastSongPath = currentSongPath;
      await _refreshSongMetadata(currentSongPath);
    }
  }


  // 鎻愬彇鏇存柊閫氱煡鐨勬柟娉?
  void updateNotification(String songPath) {
    NotificationHelper.showNotification(
      id: 1,
      title: "Playing Song",
      body: songPath.split('/').last,
      payload: null,
    );
  }

  void _handleNowPlayingChange(AudioProvider audioProvider) {
    final newPath = audioProvider.getCurrentFilePath;
    if (newPath == null || newPath == _lastSongPath) {
      return;
    }
    _lastSongPath = newPath;

    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
    final audioFiles = menuViewModel.getAudioFiles();
    final newIndex = audioFiles.indexOf(newPath);
    if (newIndex != -1 && mounted) {
      setState(() {
        currentSongIndex = newIndex;
      });
    }

    _refreshSongMetadata(newPath);
  }

  Future<void> _refreshSongMetadata(String songPath) async {
    final songTitle = songPath.split('/').last.split('.').first;
    final hasLyrics = await _fetchLyrics(songTitle);
    if (!hasLyrics && mounted) {
      setState(() {
        lyrics = [
          {'time': 0, 'lyric': '暂无歌词'},
        ];
        currentLyricIndex = 0;
      });
    }
    await _fetchSingerName(songTitle);
    await _fetchSongCoverImage(songTitle);
  }

  // 鏇存柊褰撳墠鏄剧ず鐨勬瓕璇嶇储寮?
  void updateCurrentLyricIndex(int currentTime) {
    for (int i = 0; i < lyrics.length; i++) {
      if (i == lyrics.length - 1 || (lyrics[i]['time'] <= currentTime && lyrics[i + 1]['time'] > currentTime)) {
        if (currentLyricIndex != i) {
          setState(() {
            currentLyricIndex = i;
          });
        }
        break;
      }
    }
  }

  // 鏍煎紡鍖栨椂闀?
  String formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  // 鑾峰彇姝屾墜鍚嶅瓧
  Future<void> _fetchSingerName([String? songTitle]) async {
    String? resolvedTitle = songTitle;
    if (resolvedTitle == null) {
      final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
      final audioFiles = menuViewModel.getAudioFiles();
      if (audioFiles.isEmpty) return;
      resolvedTitle = audioFiles[currentSongIndex].split('/').last.split('.').first;
    }
    String apiUrl = 'http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=$resolvedTitle&page=1';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        String responseBody = response.body;
        // 浣跨敤姝ｅ垯琛ㄨ揪寮忔彁鍙栫涓€涓瓕鎵嬪悕瀛?
        RegExp regex = RegExp(r'"singername":"([^"]+)"');
        Match? match = regex.firstMatch(responseBody);
        if (match != null) {
          setState(() {
            singerName = match.group(1)!;
          });
        }
      } else {
        print('Failed to fetch singer name: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to fetch singer name: $e');
    }
  }

  // 鑾峰彇姝屾洸灏侀潰鍥剧墖
  // 鑾峰彇姝屾洸灏侀潰鍥剧墖
  Future<void> _fetchSongCoverImage([String? songTitle]) async {
    String? resolvedTitle = songTitle;
    if (resolvedTitle == null) {
      final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
      final audioFiles = menuViewModel.getAudioFiles();
      if (audioFiles.isEmpty) return;
      resolvedTitle = audioFiles[currentSongIndex].split('/').last.split('.').first;
    }

    String apiUrl = 'https://mcapi.muwl.xyz/api/music_163.php?msg=$resolvedTitle&n=1';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // 娓呯悊 Content-Type 瀛楁
        if (response.headers['content-type'] != null) {
          response.headers['content-type'] = response.headers['content-type']!.split(';')[0];
        }

        final data = json.decode(response.body);
        if (data['status'] == 'success' && data.containsKey('img')) {
          String pictureUrl = data['img'].toString().trim();
          if (pictureUrl.isNotEmpty && pictureUrl.startsWith('http')) {
            setState(() {
              coverImageUrl = pictureUrl; // 鏇存柊灏侀潰鍥剧墖 URL
            });
          } else {
            print('Invalid picture URL: $pictureUrl');
            setState(() {
              coverImageUrl = 'lib/images/cover_art.jpg'; // 浣跨敤榛樿鍥剧墖
            });
          }
        } else {
          print('No cover image found for the song.');
          setState(() {
            coverImageUrl = 'lib/images/cover_art.jpg'; // 浣跨敤榛樿鍥剧墖
          });
        }
      } else {
        print('Failed to fetch cover image: ${response.statusCode}');
        setState(() {
          coverImageUrl = 'lib/images/cover_art.jpg'; // 浣跨敤榛樿鍥剧墖
        });
      }
    } catch (e) {
      print('Failed to fetch cover image: $e');
      setState(() {
        coverImageUrl = 'lib/images/cover_art.jpg'; // 浣跨敤榛樿鍥剧墖
      });
    }
  }
  Future<bool> _fetchLyrics([String? songTitle]) async {
    String? resolvedTitle = songTitle;
    if (resolvedTitle == null) {
      final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);
      final audioFiles = menuViewModel.getAudioFiles();
      if (audioFiles.isEmpty) return false;
      resolvedTitle = audioFiles[currentSongIndex].split('/').last.split('.').first;
    }

    String lyricUrl = 'https://api.52vmy.cn/api/music/lrc?msg=$resolvedTitle&n=1';

    try {
      final response = await http.get(Uri.parse(lyricUrl));
      if (response.statusCode == 200) {
        final parsedLyrics = LyricParser.parseLyrics(response.body);
        if (mounted) {
          setState(() {
            lyrics = parsedLyrics;
            currentLyricIndex = 0;
          });
        }
        return parsedLyrics.isNotEmpty;
      } else {
        print('Failed to fetch lyrics: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Failed to fetch lyrics: $e');
      if (mounted) {
        setState(() {
          lyrics = [];
          currentLyricIndex = 0;
        });
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuViewModel = context.watch<MenuViewModel>();
    final audioProvider = context.watch<AudioProvider>();
    final audioFiles = menuViewModel.getAudioFiles();
    final hasSongs = audioFiles.isNotEmpty;
    final safeIndex = hasSongs ? currentSongIndex.clamp(0, audioFiles.length - 1) : 0;

    int derivedIndex = safeIndex;
    if (hasSongs) {
      final playingPath = audioProvider.getCurrentFilePath;
      if (playingPath != null) {
        final playingIndex = audioFiles.indexOf(playingPath);
        if (playingIndex != -1) {
          derivedIndex = playingIndex;
        }
      }
    }

    if (hasSongs && derivedIndex != currentSongIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            currentSongIndex = derivedIndex;
          });
        }
      });
    }

    final normalizedIndex = hasSongs ? derivedIndex.clamp(0, audioFiles.length - 1) : 0;
    final currentSongPath = hasSongs ? audioFiles[normalizedIndex] : 'assets/music/1.mp3';
    // 监听 AudioProvider 的状态变化
    final duration = audioProvider.audioPlayer.duration;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 65,
                      width: 65,
                      child: NeuBox(
                        child: Center(
                          child: IconButton(icon: const Icon(
                            Icons.arrow_back,
                            size: 32,
                          ),
                            onPressed: () {
                              // 鐐瑰嚮杩斿洖鎸夐挳鏃惰烦杞埌 AboutPage
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AboutPage()),
                              );
                            },),
                        ),
                      ),
                    ),
                    const Text("P L A Y L I S T"),
                    SizedBox(
                      height: 65,
                      width: 65,
                      child: NeuBox(
                        child: IconButton(
                          icon: const Icon(
                            Icons.menu,
                            size: 32,
                          ),
                          onPressed: () {
                            showMusicListBottomSheet(
                              context,
                              onSongSelected: (selectedSongPath) {
                                setState(() {
                                  currentSongIndex = audioFiles.indexOf(selectedSongPath);
                                });
                                playCurrentSong();
                              },
                              viewModel: menuViewModel,
                            );
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                NeuBox(
                  child: SizedBox(
                    height: 300, // 鏍规嵁瀹為檯鎯呭喌璋冩暣楂樺害
                    child: PageView(
                      controller: _pageController,
                      children: [
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: Center(
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 250, // 璁剧疆鍥剧墖瀹藉害
                                    height: 250, // 璁剧疆鍥剧墖楂樺害锛屼笌瀹藉害鐩哥瓑浠ヤ繚璇佸渾褰?
                                    child: Image.network(
                                      coverImageUrl, // 浣跨敤灏侀潰鍥剧墖
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // 濡傛灉鍥剧墖鍔犺浇澶辫触锛屼娇鐢ㄩ粯璁ゅ浘鐗?
                                        return Image.asset(
                                          'lib/images/cover_art.jpg',
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        ListView.builder(
                          itemCount: lyrics.length,
                          itemBuilder: (context, index) {
                            return Text(
                              lyrics[index]['lyric'],
                              style: TextStyle(
                                color: index == currentLyricIndex ? Colors.blue : Colors.black,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            singerName, // 鏄剧ず姝屾墜鍚嶅瓧
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700),
                          ),
                          Text(
                            currentSongPath.split('/').last,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      FavoriteButton(
                        filePath: currentSongPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<Duration>(
                      stream: audioProvider.audioPlayer.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        return Text(formatDuration(position));
                      },
                    ),
                    // 闅忔満鍔熻兘鎸夐挳
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: isShuffle ? Colors.blue : null,
                      ),
                      onPressed: () {
                        setState(() {
                          isShuffle = !isShuffle;
                          isSingleLoop = false;
                          if (isShuffle && audioFiles.isNotEmpty) {
                            audioProvider.playRandomSong(audioFiles);
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isSingleLoop ? Icons.repeat_one : Icons.repeat,
                        color: isSingleLoop ? Colors.blue : null,
                      ),
                      onPressed: () {
                        setState(() {
                          isSingleLoop = !isSingleLoop;
                          isShuffle = false;
                        });
                      },
                    ),
                    Text(formatDuration(duration)),
                  ],
                ),
                const SizedBox(height: 20),
                StreamBuilder<Duration>(
                  stream: audioProvider.audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final totalDuration = audioProvider.audioPlayer.duration ?? Duration.zero;
                    final percent = totalDuration.inMilliseconds > 0
                        ? position.inMilliseconds / totalDuration.inMilliseconds
                        : 0;

                    return NeuBox(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 10, // 璁剧疆杩涘害鏉￠珮搴︼紝浣垮叾鏇寸矖
                          activeTrackColor: Colors.blue.shade200, // 杩涘害鏉″凡鎾斁閮ㄥ垎棰滆壊
                          inactiveTrackColor: Colors.grey[300], // 杩涘害鏉℃湭鎾斁閮ㄥ垎棰滆壊锛屾祬鐏拌壊
                          thumbColor: Colors.blue.shade200, // 婊戝潡棰滆壊
                          overlayColor: Colors.blue.shade200.withOpacity(0.2), // 婊戝潡鐐瑰嚮鏃剁殑瑕嗙洊棰滆壊
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), // 婊戝潡褰㈢姸鍜屽ぇ灏?
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16), // 婊戝潡鐐瑰嚮鏃惰鐩栧眰鐨勫ぇ灏?
                        ),
                        child: Slider(
                          value: percent.clamp(0.0, 1.0).toDouble(),
                          onChanged: (newValue) {
                            final newPosition = newValue * totalDuration.inMilliseconds;
                            audioProvider.audioPlayer.seek(Duration(milliseconds: newPosition.toInt()));
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40), // 澧炲姞杩涘害鏉′笌鎸夐挳涔嬮棿鐨勯棿璺?
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: NeuBox(
                          child: IconButton(
                            icon: const Icon(Icons.skip_previous, size: 32),
                            onPressed: previousSong,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: NeuBox(
                            child: IconButton(
                              //鎾斁鎸夐挳
                              icon: Icon(
                                audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              onPressed: () {
                                playCurrentSong();
                                _fetchSongCoverImage();
                              },
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: NeuBox(
                          child: IconButton(
                            icon: const Icon(Icons.skip_next, size: 32),
                            onPressed: nextSong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
