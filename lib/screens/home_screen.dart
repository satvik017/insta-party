import 'package:flutter/material.dart';
import '../models/reel_item.dart';
import '../services/sync_manager.dart';
import '../theme/app_theme.dart';
import 'watch_party_screen.dart';
import 'dual_sync_demo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isCreatingParty = false;
  bool _isJoiningParty = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = SyncManager.instance.userName;
  }

  void _showEditProfileDialog() {
    _nameController.text = SyncManager.instance.userName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Your Nickname', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person, color: AppTheme.instaOrange),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                await SyncManager.instance.updateProfile(newName: newName);
                if (mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.instaRed),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFirebaseInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.cloud_sync_rounded, color: AppTheme.instaYellow),
            const SizedBox(width: 8),
            const Text('Sync Backend', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        SyncManager.instance.isFirebaseAvailable
                            ? Icons.check_circle_rounded
                            : Icons.flash_on_rounded,
                        color: SyncManager.instance.isFirebaseAvailable
                            ? Colors.greenAccent
                            : AppTheme.instaYellow,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SyncManager.instance.service.backendType,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13),
                            ),
                            Text(
                              SyncManager.instance.isFirebaseAvailable
                                  ? 'Project: task-management-d6054'
                                  : 'Direct Sync Engine Active',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select Cloud Sync Engine:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                _engineOption(
                  'Cloud Firestore (Default)',
                  'Auto-detects project without database URL config',
                  SyncEngineType.firebaseFirestore,
                  setDialogState,
                ),
                _engineOption(
                  'Realtime Database (RTDB)',
                  'Sub-second low latency WebSocket',
                  SyncEngineType.firebaseRtdb,
                  setDialogState,
                ),
                _engineOption(
                  'Local / Direct Relay',
                  'Instant testing for 1-device / split screen',
                  SyncEngineType.localRelay,
                  setDialogState,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    '⚠️ Important: In your Firebase Console, make sure to click "Create Database" under Firestore or Realtime Database in Test Mode.',
                    style: TextStyle(fontSize: 11, color: Colors.amber, height: 1.3),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.instaRed),
            child: const Text('Save & Close'),
          ),
        ],
      ),
    );
  }

  Widget _engineOption(
    String title,
    String subtitle,
    SyncEngineType type,
    StateSetter setDialogState,
  ) {
    final isSelected = SyncManager.instance.engineType == type;
    return InkWell(
      onTap: () {
        SyncManager.instance.switchEngine(type);
        setDialogState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected ? AppTheme.instaRed : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startHostParty([String? reelUrl, String? title]) async {
    setState(() => _isCreatingParty = true);
    try {
      final initial = reelUrl ?? ReelItem.defaultCuratedReels.first.originalUrl;
      final initialTitle = title ?? ReelItem.defaultCuratedReels.first.title;

      final room = await SyncManager.instance.createParty(
        initialUrl: initial,
        title: initialTitle,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WatchPartyScreen(initialRoom: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start party: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingParty = false);
    }
  }

  Future<void> _joinParty() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code (e.g. SYNC-XXXX)')),
      );
      return;
    }

    final normalizedCode = code.startsWith('SYNC-') ? code : 'SYNC-$code';
    setState(() => _isJoiningParty = true);
    try {
      final room = await SyncManager.instance.joinParty(roomId: normalizedCode);
      if (room == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 24),
                  SizedBox(width: 10),
                  Text('Room Not Found', style: TextStyle(color: Colors.white, fontSize: 17)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not find room "$normalizedCode" on the cloud database.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To fix this in Firebase Console:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '1. Open your Firebase project: task-management-d6054\n'
                          '2. Click Build > Firestore Database (or Realtime Database)\n'
                          '3. Click "Create Database" and choose "Start in test mode"\n'
                          '4. Host creates the room, and guest joins with the code!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: AppTheme.instaRed)),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        _joinCodeController.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WatchPartyScreen(initialRoom: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoiningParty = false);
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curatedReels = ReelItem.defaultCuratedReels;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Backend Status & Profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sync backend badge
                  GestureDetector(
                    onTap: _showFirebaseInfoDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SyncManager.instance.isFirebaseAvailable ? Icons.cloud_done : Icons.flash_on,
                            size: 14,
                            color: AppTheme.instaYellow,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            SyncManager.instance.isFirebaseAvailable ? 'Firebase RTDB' : 'Real-Time Sync',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline, size: 12, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),

                  // Profile Chip
                  GestureDetector(
                    onTap: _showEditProfileDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.instaGradient,
                            ),
                            child: const Icon(Icons.person, size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            SyncManager.instance.userName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Hero Header with Instagram Logo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.instaRed.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/instagram_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.instaGradient.createShader(bounds),
                        child: const Text(
                          'InstaParty',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.instaPurple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.instaRed.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'LIVE REELS SYNC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.instaYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Watch Instagram Reels together in real time with synchronized playback, live reactions & chat.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),

              const SizedBox(height: 28),

              // Action Card 1: Start Watch Party (Host)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26122F), Color(0xFF1B1424)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.instaPurple.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.instaPurple.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.instaRed.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/images/instagram_logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host a Watch Party',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Get a room code & invite a friend',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.instaGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: _isCreatingParty ? null : () => _startHostParty(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isCreatingParty
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Party Room',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Card 2: Join Watch Party (Guest)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.login_rounded, color: AppTheme.instaOrange, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join with Party Code',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Enter code provided by your host',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _joinCodeController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'SYNC-XXXX',
                              hintStyle: const TextStyle(letterSpacing: 1.2, color: AppTheme.textMuted),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isJoiningParty ? null : _joinParty,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surface,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.instaOrange, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isJoiningParty
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Card 3: Dual-User Split Screen Live Test
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DualSyncDemoScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.splitscreen_rounded, color: Colors.tealAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dual-User Realtime Preview',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              'See Host & Guest side-by-side syncing on this device',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Curated Reels Shelf
              const Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppTheme.instaRed, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Trending Reels Library',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: curatedReels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final reel = curatedReels[index];
                    return InkWell(
                      onTap: () => _startHostParty(reel.originalUrl, reel.title),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.instaPurple.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reel.category,
                                style: const TextStyle(fontSize: 10, color: AppTheme.instaOrange, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reel.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, size: 12, color: AppTheme.instaYellow),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Start Party',
                                      style: TextStyle(fontSize: 11, color: AppTheme.instaYellow, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
