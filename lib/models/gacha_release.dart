class GachaRelease {
  const GachaRelease({
    required this.id,
    required this.title,
    required this.manufacturer,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.summary,
    required this.tags,
    required this.marketPrices,
    this.series,
    this.releaseDate,
    this.priceYen,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String manufacturer;
  final String sourceLabel;
  final String sourceUrl;
  final String summary;
  final String? series;
  final String? releaseDate;
  final int? priceYen;
  final String? imageUrl;
  final List<String> tags;
  final List<MarketplacePrice> marketPrices;

  DateTime? get releaseDateTime {
    if (releaseDate == null || releaseDate!.isEmpty) {
      return null;
    }
    return DateTime.tryParse(releaseDate!);
  }

  factory GachaRelease.fromJson(Map<String, dynamic> json) {
    int? parsePrice(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          return int.tryParse(digits);
        }
      }
      return null;
    }

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((item) => item.toString()).toList()
        : const <String>[];
    final rawMarketPrices = json['marketPrices'];
    final marketPrices = rawMarketPrices is List
        ? rawMarketPrices
              .whereType<Map<String, dynamic>>()
              .map(MarketplacePrice.fromJson)
              .toList()
        : const <MarketplacePrice>[];

    return GachaRelease(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      manufacturer: (json['manufacturer'] ?? '不明').toString(),
      sourceLabel: (json['sourceLabel'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      series: json['series']?.toString(),
      releaseDate: json['releaseDate']?.toString(),
      priceYen: parsePrice(json['priceYen']),
      imageUrl: json['imageUrl']?.toString(),
      tags: tags,
      marketPrices: marketPrices,
    );
  }
}

class MarketplacePrice {
  const MarketplacePrice({
    required this.marketplace,
    required this.searchUrl,
    required this.sampleCount,
    required this.minPriceYen,
    required this.medianPriceYen,
    required this.maxPriceYen,
    required this.updatedAt,
  });

  final String marketplace;
  final String searchUrl;
  final int sampleCount;
  final int minPriceYen;
  final int medianPriceYen;
  final int maxPriceYen;
  final String updatedAt;

  factory MarketplacePrice.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          return int.tryParse(digits) ?? 0;
        }
      }
      return 0;
    }

    return MarketplacePrice(
      marketplace: (json['marketplace'] ?? '').toString(),
      searchUrl: (json['searchUrl'] ?? '').toString(),
      sampleCount: parseInt(json['sampleCount']),
      minPriceYen: parseInt(json['minPriceYen']),
      medianPriceYen: parseInt(json['medianPriceYen']),
      maxPriceYen: parseInt(json['maxPriceYen']),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}
