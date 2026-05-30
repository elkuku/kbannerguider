import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../models/banner_item.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/drive_service.dart';
import '../services/location_service.dart';
import 'banner_detail_page.dart';

class BannerListPage extends StatefulWidget {
  BannerListPage({
    super.key,
    LocationService? locationService,
    BannerService? bannerService,
    AuthService? authService,
    DriveService? driveService,
  })  : _locationService = locationService ?? const LocationService(),
        _bannerService = bannerService ?? BannerService(),
        _authService = authService,
        _driveService = driveService;

  final LocationService _locationService;
  final BannerService _bannerService;
  final AuthService? _authService;
  final DriveService? _driveService;

  @override
  State<BannerListPage> createState() => _BannerListPageState();
}

class _BannerListPageState extends State<BannerListPage> {
  List<BannerItem> _banners = [];
  bool _loading = false;
  String? _error;
  Position? _position;
  GoogleSignInAccount? _user;
  Map<String, String> _listTypes = {};
  String? _authError;
  // null = All; 'todo'/'done'/'blacklist'/'unsorted' = filtered
  String? _activeFilter;

  bool get _isSignedIn => _user != null;

  List<BannerItem> get _filteredBanners {
    if (_activeFilter == null) return _banners;
    if (_activeFilter == 'unsorted') {
      return _banners.where((b) => !_listTypes.containsKey(b.id)).toList();
    }
    return _banners.where((b) => _listTypes[b.id] == _activeFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _initAuth();
  }

  void _initAuth() {
    final auth = widget._authService;
    if (auth == null) return;
    setState(() => _user = auth.currentUser);
    auth.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          setState(() {
            _user = user;
            _authError = null;
          });
          _loadDriveData();
        case GoogleSignInAuthenticationEventSignOut():
          setState(() {
            _user = null;
            _listTypes = {};
            _activeFilter = null;
          });
      }
    });
    if (auth.currentUser != null) _loadDriveData();
  }

  Future<void> _loadDriveData() async {
    final drive = widget._driveService;
    if (drive == null) return;
    final types = await drive.loadListTypes();
    if (mounted) setState(() => _listTypes = types);
  }

  Future<void> _fetchBanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await widget._locationService.getCurrentPosition();
      setState(() => _position = position);
      final banners = await widget._bannerService.fetchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      setState(() {
        _banners = banners;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() => _authError = null);
    try {
      await widget._authService?.signIn();
    } catch (e) {
      if (mounted) setState(() => _authError = e.toString());
    }
  }

  Future<void> _signOut() => widget._authService?.signOut() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Banners'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchBanners,
          ),
          if (widget._authService != null) _buildAccountButton(),
        ],
      ),
      body: Column(
        children: [
          // Debug panel: visible only when auth is configured and user is not signed in
          if (widget._authService != null && !_isSignedIn)
            _AuthDebugPanel(
              authError: _authError,
              position: _position,
              onSignIn: _signIn,
            ),
          // Filter bar: visible only when signed in and banners are loaded
          if (_isSignedIn && _banners.isNotEmpty)
            _FilterBar(
              activeFilter: _activeFilter,
              listTypes: _listTypes,
              banners: _banners,
              onFilterChanged: (f) => setState(() => _activeFilter = f),
            ),
          // Drive debug card: visible only when signed in
          if (_isSignedIn && widget._driveService != null)
            _DriveDebugCard(driveService: widget._driveService!),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildAccountButton() {
    if (!_isSignedIn) {
      return IconButton(
        icon: const Icon(Icons.account_circle_outlined),
        tooltip: 'Sign in with Google',
        onPressed: _signIn,
      );
    }
    return PopupMenuButton<String>(
      tooltip: _user!.displayName ?? _user!.email,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundImage: _user!.photoUrl != null
              ? NetworkImage(_user!.photoUrl!)
              : null,
          child: Text(
            (_user!.displayName ?? _user!.email)[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user!.displayName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                _user!.email,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
      onSelected: (value) {
        if (value == 'signout') _signOut();
      },
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchBanners,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filteredBanners;

    if (_banners.isEmpty) {
      return const Center(child: Text('No banners found nearby.'));
    }

    if (visible.isEmpty) {
      return const Center(
        child: Text('No banners match the selected filter.'),
      );
    }

    return Column(
      children: [
        if (_position != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Text(
              'Location: ${_position!.latitude.toStringAsFixed(5)}, '
              '${_position!.longitude.toStringAsFixed(5)}  '
              '· ${_banners.length} banners',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final banner = visible[index];
              final listType = _isSignedIn ? _listTypes[banner.id] : null;
              return ListTile(
                onTap: () async {
                  final updated = await Navigator.push<Map<String, String>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BannerDetailPage(
                        banner: banner,
                        bannerService: widget._bannerService,
                        driveService:
                            _isSignedIn ? widget._driveService : null,
                        listTypes: _listTypes,
                      ),
                    ),
                  );
                  if (updated != null) setState(() => _listTypes = updated);
                },
                leading: Hero(
                  tag: 'banner-${banner.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      banner.pictureUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.map, size: 48),
                    ),
                  ),
                ),
                title: Text(banner.title),
                subtitle: banner.numberOfMissions != null
                    ? Text(
                        '${banner.numberOfMissions} mission'
                        '${banner.numberOfMissions == 1 ? '' : 's'}',
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (listType != null && listType != 'none')
                      _ListTypeBadge(listType: listType),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Auth debug panel ────────────────────────────────────────────────────────

class _AuthDebugPanel extends StatelessWidget {
  const _AuthDebugPanel({
    required this.authError,
    required this.position,
    required this.onSignIn,
  });

  final String? authError;
  final Position? position;
  final VoidCallback onSignIn;

  bool get _configured =>
      googleOAuthClientId !=
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  @override
  Widget build(BuildContext context) {
    final hasError = authError != null;
    final color = hasError
        ? Colors.red
        : _configured
            ? Colors.blue
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasError
                      ? Icons.error_outline
                      : _configured
                          ? Icons.lock_open_outlined
                          : Icons.warning_amber_outlined,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Auth — not signed in',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Row('Client ID',
                _configured
                    ? '${googleOAuthClientId.substring(0, 20)}…'
                    : '⚠ NOT CONFIGURED — see SETUP.md'),
            _Row('Drive scope', 'drive.file'),
            if (position != null)
              _Row('Location',
                  '${position!.latitude.toStringAsFixed(4)}, '
                  '${position!.longitude.toStringAsFixed(4)}'),
            if (hasError) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  authError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            if (_configured)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login, size: 15),
                  label: const Text('Sign in with Google',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilter,
    required this.listTypes,
    required this.banners,
    required this.onFilterChanged,
  });

  final String? activeFilter;
  final Map<String, String> listTypes;
  final List<BannerItem> banners;
  final ValueChanged<String?> onFilterChanged;

  int _count(String? filter) {
    if (filter == null) return banners.length;
    if (filter == 'unsorted') {
      return banners.where((b) => !listTypes.containsKey(b.id)).length;
    }
    return banners.where((b) => listTypes[b.id] == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    const chips = [
      (null, 'All', Icons.list_outlined, Colors.grey),
      ('todo', 'To-do', Icons.bookmark_outline, Colors.blue),
      ('done', 'Done', Icons.check_circle_outline, Colors.green),
      ('blacklist', 'Skip', Icons.block, Colors.red),
      ('unsorted', 'Unsorted', Icons.label_off_outlined, Colors.grey),
    ];

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: chips.map<Widget>((chip) {
            final (value, label, icon, baseColor) = chip;
            final color = baseColor as Color;
            final selected = activeFilter == value;
            final count = _count(value);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: selected,
                avatar: Icon(icon, size: 15,
                    color: selected ? color : Colors.grey),
                label: Text('$label  $count',
                    style: const TextStyle(fontSize: 12)),
                onSelected: (_) =>
                    onFilterChanged(selected ? null : value),
                selectedColor: color.withValues(alpha: 0.15),
                checkmarkColor: color,
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Drive debug card ────────────────────────────────────────────────────────

class _DriveDebugCard extends StatelessWidget {
  const _DriveDebugCard({required this.driveService});

  final DriveService driveService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: driveService.debugLog,
      builder: (context, log, _) {
        return Card(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          color: log.contains('error') || log.contains('Error')
              ? Colors.red.shade50
              : Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: log.contains('error') || log.contains('Error')
                  ? Colors.red.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  log.contains('error') || log.contains('Error')
                      ? Icons.error_outline
                      : Icons.cloud_outlined,
                  size: 15,
                  color: log.contains('error') || log.contains('Error')
                      ? Colors.red
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── List type badge ─────────────────────────────────────────────────────────

class _ListTypeBadge extends StatelessWidget {
  const _ListTypeBadge({required this.listType});
  final String listType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (listType) {
      'todo' => (Icons.bookmark_outline, Colors.blue),
      'done' => (Icons.check_circle_outline, Colors.green),
      'blacklist' => (Icons.block, Colors.red),
      _ => (Icons.label_outline, Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
