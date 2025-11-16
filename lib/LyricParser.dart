import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricParser {
  static Future<List<Map<String, dynamic>>> parseLyricsFromUrl(String lyricUrl) async {
    try {
      final response = await http.get(Uri.parse(lyricUrl));
      if (response.statusCode == 200) {
        return parseLyrics(response.body);
      } else {
        print('Failed to load lyric: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Failed to fetch lyric: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> parseLyrics(String lrcText) {
    List<Map<String, dynamic>> result = [];
    RegExp regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    List<String> lines = lrcText.split('\n');
    for (String line in lines) {
      Match? match = regExp.firstMatch(line);
      if (match != null) {
        int minutes = int.parse(match.group(1)!);
        int seconds = int.parse(match.group(2)!);
        String milliGroup = match.group(3)!;
        int milliseconds = milliGroup.length == 3
            ? int.parse(milliGroup)
            : int.parse(milliGroup) * 10;
        String lyric = match.group(4)!.trim();
        // 过滤掉空歌词
        if (lyric.isNotEmpty) {
          int time = minutes * 60000 + seconds * 1000 + milliseconds;
          result.add({'time': time, 'lyric': lyric});
        }
      }
    }
    result.sort((a, b) => a['time'].compareTo(b['time']));
    return result;
  }
}
