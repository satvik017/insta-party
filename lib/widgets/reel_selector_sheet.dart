import 'package:flutter/material.dart';
import '../models/reel_item.dart';
import '../theme/app_theme.dart';

class ReelSelectorSheet extends StatefulWidget {
  final String currentReelUrl;
  final Function(String newUrl, String title) onSelectReel;

  const ReelSelectorSheet({
    super.key,
    required this.currentReelUrl,
    required this.onSelectReel,
  });

  @override
  State<ReelSelectorSheet> createState() => _ReelSelectorSheetState();
}

class _ReelSelectorSheetState extends State<ReelSelectorSheet> {
  final TextEditingController _urlController = TextEditingController();
  String? _validationError;
  String _selectedCategory = 'All';

  final List<ReelItem> _curatedReels = ReelItem.defaultCuratedReels;

  void _handleCustomUrlSubmit() {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() => _validationError = 'Please paste a reel link');
      return;
    }

    final shortcode = ReelItem.extractShortcode(input);
    if (shortcode == null) {
      setState(() => _validationError = 'Invalid Instagram Reel URL');
      return;
    }

    setState(() => _validationError = null);
    widget.onSelectReel(
      'https://www.instagram.com/reel/$shortcode/',
      'Custom Reel ($shortcode)',
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Nature', 'Pets', 'Travel', 'Sports', 'Comedy', 'Art'];
    final filteredReels = _selectedCategory == 'All'
        ? _curatedReels
        : _curatedReels.where((r) => r.category == _selectedCategory).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.instaGradient.createShader(bounds),
                  child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Change Synced Reel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Paste custom URL card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: AppTheme.instaOrange),
                      SizedBox(width: 6),
                      Text(
                        'Paste Any Instagram Reel Link',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'https://www.instagram.com/reel/C8...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.instaGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: _handleCustomUrlSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Sync',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _validationError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Categories bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.instaRed,
                      backgroundColor: AppTheme.surfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? AppTheme.instaRed : AppTheme.border,
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Curated reels list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredReels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reel = filteredReels[index];
                final isCurrent = widget.currentReelUrl.contains(
                  ReelItem.extractShortcode(reel.originalUrl) ?? '###',
                );

                return InkWell(
                  onTap: () {
                    widget.onSelectReel(reel.originalUrl, reel.title);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.instaPurple.withOpacity(0.25)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? AppTheme.instaRed : AppTheme.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.instaGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reel.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    reel.creator,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.instaYellow,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      reel.category,
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.instaRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Playing Now',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
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
