import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/gacha_release.dart';
import '../models/x_post.dart';

class DataApi {
  Future<List<GachaRelease>> fetchReleases() async {
    final jsonList = await _loadJsonList(
      webPath: 'data/releases.json',
      assetPath: 'assets/data/releases.json',
    );

    final releases = jsonList
        .map(GachaRelease.fromJson)
        .where((item) => item.title.isNotEmpty && item.sourceUrl.isNotEmpty)
        .toList();

    releases.sort((a, b) {
      final left = a.releaseDateTime;
      final right = b.releaseDateTime;

      if (left == null && right == null) {
        return a.title.compareTo(b.title);
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return right.compareTo(left);
    });

    return releases;
  }

  Future<List<XPost>> fetchXPosts() async {
    final jsonList = await _loadJsonList(
      webPath: 'data/x_posts.json',
      assetPath: 'assets/data/x_posts.json',
    );

    final posts = jsonList
        .map(XPost.fromJson)
        .where((item) => item.url.isNotEmpty)
        .toList();

    posts.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return posts;
  }

  Future<List<Map<String, dynamic>>> _loadJsonList({
    required String webPath,
    required String assetPath,
  }) async {
    if (kIsWeb) {
      try {
        final uri = Uri.base.resolve(
          '$webPath?t=${DateTime.now().millisecondsSinceEpoch}',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            return decoded.whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {
        // Fallback to bundled asset below.
      }
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('データ読み込み失敗: $assetPath ($error)');
      }
    }

    return const [];
  }
}
