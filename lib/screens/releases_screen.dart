import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/gacha_release.dart';

class ReleasesScreen extends StatefulWidget {
  const ReleasesScreen({super.key, required this.releases});

  final List<GachaRelease> releases;

  @override
  State<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends State<ReleasesScreen> {
  String _selectedManufacturer = 'すべて';

  @override
  Widget build(BuildContext context) {
    final manufacturers = {
      for (final release in widget.releases) release.manufacturer,
    }.toList()..sort();
    final filters = ['すべて', ...manufacturers];

    final filtered = widget.releases.where((release) {
      if (_selectedManufacturer == 'すべて') {
        return true;
      }
      return release.manufacturer == _selectedManufacturer;
    }).toList();

    if (widget.releases.isEmpty) {
      return const Center(
        child: Text(
          '新作情報がありません\nデータ更新スクリプトを実行してください。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: filters.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final selected = filter == _selectedManufacturer;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedManufacturer = filter;
                    });
                  },
                  selectedColor: const Color(0xFF154A78),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected ? const Color(0xFF154A78) : Colors.black12,
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final release = filtered[index];
              return _ReleaseCard(release: release);
            },
          ),
        ),
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});

  final GachaRelease release;

  @override
  Widget build(BuildContext context) {
    final price = release.priceYen != null ? '¥${release.priceYen}' : '価格未定';
    final date = release.releaseDate ?? '日付未定';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE7ECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF154A78).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    release.manufacturer,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF154A78),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              release.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if ((release.series ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                release.series!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              release.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openUrl(release.sourceUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    release.sourceLabel.isEmpty ? '公式サイト' : release.sourceLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _openUrl(release.sourceUrl),
              child: Text(
                '公式URL: ${_displayUrl(release.sourceUrl)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF154A78),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (release.marketPrices.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                '中古相場（メルカリ等）',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Column(
                children: release.marketPrices
                    .map(
                      (market) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF2F5F9),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${market.marketplace}: ¥${market.medianPriceYen} (最安 ¥${market.minPriceYen} / 最高 ¥${market.maxPriceYen})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${market.sampleCount}件',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _openUrl(market.searchUrl),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              tooltip: '${market.marketplace}検索を開く',
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (release.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: release.tags
                    .take(4)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF2F5F9),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  String _displayUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    return uri.host + uri.path;
  }
}
