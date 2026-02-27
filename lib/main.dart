import 'package:flutter/material.dart';

import 'models/gacha_release.dart';
import 'models/x_post.dart';
import 'screens/releases_screen.dart';
import 'screens/x_posts_screen.dart';
import 'services/data_api.dart';

void main() {
  runApp(const GachaInfoApp());
}

class GachaInfoApp extends StatelessWidget {
  const GachaInfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ガチャガチャ情報',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF154A78),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F9FC),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dataApi = DataApi();

  List<GachaRelease> _releases = const [];
  List<XPost> _posts = const [];

  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await Future.wait([
        _dataApi.fetchReleases(),
        _dataApi.fetchXPosts(),
      ]);

      setState(() {
        _releases = result[0] as List<GachaRelease>;
        _posts = result[1] as List<XPost>;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ガチャガチャ情報アプリ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            tooltip: '更新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.toys_outlined),
            selectedIcon: Icon(Icons.toys),
            label: '新作ガチャ',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'X速報',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _releases.isEmpty && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('再試行')),
            ],
          ),
        ),
      );
    }

    if (_currentIndex == 0) {
      return ReleasesScreen(releases: _releases);
    }
    return XPostsScreen(posts: _posts);
  }
}
