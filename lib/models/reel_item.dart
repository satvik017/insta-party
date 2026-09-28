class ReelItem {
  final String id;
  final String title;
  final String creator;
  final String originalUrl;
  final String category;
  final String? previewDescription;

  const ReelItem({
    required this.id,
    required this.title,
    required this.creator,
    required this.originalUrl,
    required this.category,
    this.previewDescription,
  });

  /// Extracts the Instagram shortcode from any format
  static String? extractShortcode(String url) {
    final clean = url.trim();
    // Match /reel/CODE/ or /reels/CODE/ or /p/CODE/
    final regExp = RegExp(r'(?:reel|reels|p)\/([A-Za-z0-9_-]+)');
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    // If user entered only the shortcode
    if (RegExp(r'^[A-Za-z0-9_-]{8,15}$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  /// Converts standard Instagram link to an embed URL that is clean and autoplay-ready
  static String formatToEmbedUrl(String url) {
    final shortcode = extractShortcode(url);
    if (shortcode != null) {
      return 'https://www.instagram.com/reel/$shortcode/embed/';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://www.instagram.com/reel/$url/embed/';
  }

  /// Converts to standard Instagram direct reel URL
  static String formatToDirectUrl(String url) {
    final shortcode = extractShortcode(url);
    if (shortcode != null) {
      return 'https://www.instagram.com/reel/$shortcode/';
    }
    return url;
  }

  String get embedUrl => formatToEmbedUrl(originalUrl);
  String get directUrl => formatToDirectUrl(originalUrl);

  /// Curated collection of popular, public Instagram reels for instant watch parties
  static List<ReelItem> get defaultCuratedReels => [
        const ReelItem(
          id: 'nature_drone',
          title: 'Majestic Dolomites Drone Reel',
          creator: '@nature.escape',
          originalUrl: 'https://www.instagram.com/reel/C7o6Bv8tWj9/',
          category: 'Nature',
          previewDescription: 'Sweeping cinematic aerials over the peaks of Italy',
        ),
        const ReelItem(
          id: 'cute_puppy',
          title: 'Golden Retriever Zoomies',
          creator: '@doggo_vibes',
          originalUrl: 'https://www.instagram.com/reel/C8qL7MhPR2b/',
          category: 'Pets',
          previewDescription: 'Pure joy and wholesome moments',
        ),
        const ReelItem(
          id: 'tokyo_night',
          title: 'Cyberpunk Tokyo Night Walk',
          creator: '@tokyo_streetview',
          originalUrl: 'https://www.instagram.com/reel/C6yG2v1Kz3X/',
          category: 'Travel',
          previewDescription: 'Rain reflections and neon lights in Shinjuku',
        ),
        const ReelItem(
          id: 'skate_trick',
          title: 'Impossible Sunset Kickflip Slow-Mo',
          creator: '@skater_daily',
          originalUrl: 'https://www.instagram.com/reel/C9aP9oOty8C/',
          category: 'Sports',
          previewDescription: 'Silhouetted 120fps kickflip with ocean backdrop',
        ),
        const ReelItem(
          id: 'coffee_art',
          title: 'Hypnotic Swan Latte Art Pour',
          creator: '@barista_craft',
          originalUrl: 'https://www.instagram.com/reel/C5j12F7RtqQ/',
          category: 'Art',
          previewDescription: 'Precision foam pouring technique',
        ),
        const ReelItem(
          id: 'comedy_sync',
          title: 'When You Agree To Go Out Then Regret It',
          creator: '@humor_central',
          originalUrl: 'https://www.instagram.com/reel/C4x8H9NqZ_M/',
          category: 'Comedy',
          previewDescription: 'Relatable daily situations',
        ),
      ];
}
