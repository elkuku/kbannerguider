import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/banner_item.dart';
import '../version.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/cache_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../utils/format.dart';
import 'banner_detail_page.dart';
import 'location_picker_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/full_image_dialog.dart';

class BannerListPage extends StatefulWidget {
  BannerListPage({
    super.key,
    LocationService? locationService,
    BannerService? bannerService,
    AuthService? authService,
    LocalStorageService? storageService,
    this.onToggleTheme,
    this.isDarkMode = true,
  })  : _locationService = locationService ?? const LocationService(),
        _bannerService = bannerService ?? BannerService(),
        _authService = authService,
        _storageService = storageService ?? LocalStorageService();

  final LocationService _locationService;
  final BannerService _bannerService;
  final AuthService? _authService;
  final LocalStorageService _storageService;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  @override
  State<BannerListPage> createState() => _BannerListPageState();
}

class _BannerListPageState extends State<BannerListPage>
    with SingleTickerProviderStateMixin {
  // ── Nearby tab state ──────────────────────────────────────────────────
  List<BannerItem> _banners = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  double? _fetchLat;
  double? _fetchLng;
  String? _error;
  Set<String> _hiddenFilters = {};
  final ScrollController _nearbyScrollController = ScrollController();

  // ── To-do tab state ───────────────────────────────────────────────────
  List<BannerItem> _todoBanners = [];
  bool _loadingTodo = false;
  final _cache = CacheService();

  // ── Shared state ──────────────────────────────────────────────────────
  Position? _position;
  LatLng? _customCenter;
  bool _isSignedIn = false;
  bool _checkingAuth = false;
  Map<String, String> _listTypes = {};
  String? _authError;
  late final TabController _tabController;

  // ─────────────────────────────────────────────────────────────────────

  List<BannerItem> get _filteredBanners {
    if (_hiddenFilters.isEmpty) return _banners;
    return _banners.where((b) {
      final type = _listTypes[b.id];
      final key = (type == null || type == 'none') ? 'unsorted' : type;
      return !_hiddenFilters.contains(key);
    }).toList();
  }

  double? _distanceMeters(BannerItem banner) {
    if (_position == null ||
        banner.startLatitude == null ||
        banner.startLongitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      banner.startLatitude!,
      banner.startLongitude!,
    );
  }

  String? _formatDistance(BannerItem banner) {
    final m = _distanceMeters(banner);
    if (m == null) return null;
    return formatMeters(m.round());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _nearbyScrollController.addListener(_onNearbyScroll);
    _loadLocalData();
    _fetchBanners();
    _checkAuth();
  }

  @override
  void dispose() {
    _nearbyScrollController.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_loadingTodo) {
      _fetchTodoBanners();
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  Future<void> _checkAuth() async {
    final auth = widget._authService;
    if (auth == null) return;
    final loggedIn = await auth.isLoggedIn();
    if (!mounted) return;
    setState(() => _isSignedIn = loggedIn);
    if (loggedIn && _tabController.index == 1) {
      _fetchTodoBanners();
    }
  }

  Future<void> _signIn() async {
    final auth = widget._authService;
    if (auth == null) return;
    setState(() {
      _authError = null;
      _checkingAuth = true;
    });
    try {
      await auth.login(context);
      if (!mounted) return;
      setState(() {
        _isSignedIn = true;
        _checkingAuth = false;
      });
      _fetchBanners();
      _fetchTodoBanners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authError = e.toString();
        _checkingAuth = false;
      });
    }
  }

  Future<void> _signOut() async {
    await widget._authService?.logout();
    await _cache.clearTodoBanners();
    if (!mounted) return;
    setState(() {
      _isSignedIn = false;
      _todoBanners = [];
    });
    _fetchBanners();
    _fetchTodoBanners();
  }

  // ── Local data ─────────────────────────────────────────────────────────

  Future<void> _loadLocalData() async {
    final types = await widget._storageService.loadListTypes();
    if (!mounted) return;
    setState(() => _listTypes = types);
    if (_tabController.index == 1) _fetchTodoBanners();
  }

  // ── Nearby fetching ────────────────────────────────────────────────────

  void _onNearbyScroll() {
    if (_nearbyScrollController.position.pixels >=
            _nearbyScrollController.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _fetchMoreBanners();
    }
  }

  Future<String?> _getToken() => widget._authService?.getAccessToken() ?? Future.value(null);

  /// Merges server-returned listTypes into local storage and state.
  Future<void> _mergeListTypes(List<BannerItem> banners) async {
    final serverTypes = {
      for (final b in banners)
        if (b.listType != null && b.listType != 'none') b.id: b.listType!,
    };
    if (serverTypes.isEmpty) return;
    final merged = Map<String, String>.of(_listTypes)..addAll(serverTypes);
    if (merged.length == _listTypes.length &&
        merged.entries.every((e) => _listTypes[e.key] == e.value)) {
      return;
    }
    setState(() => _listTypes = merged);
    await widget._storageService.saveListTypes(merged);
  }

  Future<void> _fetchBanners() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      double lat, lng;
      if (_customCenter != null) {
        lat = _customCenter!.latitude;
        lng = _customCenter!.longitude;
        widget._locationService.getCurrentPosition().then((pos) {
          if (mounted) setState(() => _position = pos);
        }).catchError((_) {});
      } else {
        final position = await widget._locationService.getCurrentPosition();
        setState(() => _position = position);
        lat = position.latitude;
        lng = position.longitude;
      }
      _fetchLat = lat;
      _fetchLng = lng;
      final token = _isSignedIn ? await _getToken() : null;
      final banners = await widget._bannerService.fetchNearby(
        latitude: lat,
        longitude: lng,
        accessToken: token,
      );
      setState(() {
        _banners = banners;
        _loading = false;
        _hasMore = banners.length >= BannerService.pageSize;
      });
      if (token != null) unawaited(_mergeListTypes(banners));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchMoreBanners() async {
    if (_loadingMore || !_hasMore || _fetchLat == null || _fetchLng == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final token = _isSignedIn ? await _getToken() : null;
      final more = await widget._bannerService.fetchNearby(
        latitude: _fetchLat!,
        longitude: _fetchLng!,
        offset: _banners.length,
        accessToken: token,
      );
      setState(() {
        _banners = [..._banners, ...more];
        _loadingMore = false;
        _hasMore = more.length >= BannerService.pageSize;
      });
      if (token != null) unawaited(_mergeListTypes(more));
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  // ── To-do fetching ─────────────────────────────────────────────────────

  Future<void> _fetchTodoBanners() async {
    if (_loadingTodo) return;

    // When signed in: fetch authoritative list from Bannergress API.
    if (_isSignedIn) {
      await _fetchTodosFromApi();
      return;
    }

    // Not signed in: derive from local list types.
    await _fetchTodosFromLocalTypes();
  }

  Future<void> _fetchTodosFromApi() async {
    final auth = widget._authService;
    if (auth == null) return;

    // Show cached banners immediately
    final cached = await _cache.loadTodoBanners();
    if (cached != null && mounted) {
      setState(() => _todoBanners = cached);
    }

    setState(() => _loadingTodo = true);

    try {
      String? token = await auth.getAccessToken();
      if (token == null) {
        setState(() => _loadingTodo = false);
        return;
      }

      List<BannerItem> todos;
      try {
        todos = await widget._bannerService.fetchTodos(accessToken: token);
      } on SessionExpiredException {
        // Token expired — try refresh once
        token = await auth.refreshIfNeeded();
        if (token == null) {
          if (mounted) setState(() { _isSignedIn = false; _loadingTodo = false; });
          return;
        }
        todos = await widget._bannerService.fetchTodos(accessToken: token);
      }

      // Sort by distance if GPS available
      if (_position != null) {
        todos.sort((a, b) {
          final da = _distanceMeters(a);
          final db = _distanceMeters(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      }

      unawaited(_cache.saveTodoBanners(todos));
      if (mounted) setState(() { _todoBanners = todos; _loadingTodo = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingTodo = false);
    }
  }

  Future<void> _fetchTodosFromLocalTypes() async {
    final todoIds = _listTypes.entries
        .where((e) => e.value == 'todo')
        .map((e) => e.key)
        .toList();

    if (todoIds.isEmpty) {
      await _cache.clearTodoBanners();
      setState(() {
        _todoBanners = [];
        _loadingTodo = false;
      });
      return;
    }

    // Show cached banners immediately while fetching fresh data
    final cachedBanners = await _cache.loadTodoBanners();
    if (cachedBanners != null && mounted) {
      setState(() => _todoBanners = cachedBanners);
    }

    setState(() => _loadingTodo = true);

    final fetched = <BannerItem>[];
    await Future.wait(
      todoIds.map((id) async {
        try {
          final banner = await widget._bannerService.fetchById(id);
          fetched.add(banner);
          if (mounted) setState(() => _todoBanners = List.of(fetched));
        } catch (_) {}
      }),
    );

    if (_position != null) {
      fetched.sort((a, b) {
        final da = _distanceMeters(a);
        final db = _distanceMeters(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    unawaited(_cache.saveTodoBanners(fetched));
    if (mounted) {
      setState(() {
        _todoBanners = fetched;
        _loadingTodo = false;
      });
    }
  }

  // ── Location picker ────────────────────────────────────────────────────

  Future<void> _openLocationPicker() async {
    LatLng? initial = _customCenter;
    if (initial == null && _position != null) {
      initial = LatLng(_position!.latitude, _position!.longitude);
    }
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
          builder: (_) => LocationPickerPage(initialCenter: initial)),
    );
    if (result != null) {
      setState(() => _customCenter = result);
      _fetchBanners();
    }
  }

  void _clearCustomCenter() {
    setState(() => _customCenter = null);
    _fetchBanners();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _listTypes);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KBannerGuider'),
              Text(
                appVersion,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: widget.onToggleTheme,
              tooltip: widget.isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading
                  ? null
                  : () {
                      _fetchBanners();
                      if (_tabController.index == 1) _fetchTodoBanners();
                    },
            ),
            if (widget._authService != null) _buildAccountButton(),
          ],
        ),
        body: Column(
          children: [
            _LocationBar(
              position: _position,
              customCenter: _customCenter,
              onPickLocation: _openLocationPicker,
              onClearCustom: _clearCustomCenter,
            ),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.place_outlined),
                  text:
                      'Nearby${_banners.isNotEmpty ? ' (${_banners.length})' : ''}',
                ),
                Tab(
                  icon: const Icon(Icons.bookmark_outline),
                  text:
                      'To-do${_todoBanners.isNotEmpty ? ' (${_todoBanners.length})' : ''}',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNearbyTab(),
                  _buildTodoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountButton() {
    if (_checkingAuth) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (!_isSignedIn) {
      return IconButton(
        icon: const Icon(Icons.account_circle_outlined),
        tooltip: 'Sign in to Bannergress',
        onPressed: _signIn,
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Bannergress account',
      icon: const Icon(Icons.account_circle, color: Colors.white),
      itemBuilder: (_) => [
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'Signed in to Bannergress',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
      onSelected: (v) {
        if (v == 'signout') _signOut();
      },
    );
  }

  // ── Nearby tab ─────────────────────────────────────────────────────────

  Widget _buildNearbyTab() {
    return Column(
      children: [
        if (widget._authService != null && !_isSignedIn)
          _BannergressSignInBanner(
            authError: _authError,
            onSignIn: _signIn,
          ),
        if (_banners.isNotEmpty)
          _FilterBar(
            hiddenFilters: _hiddenFilters,
            listTypes: _listTypes,
            banners: _banners,
            onChanged: (h) => setState(() => _hiddenFilters = h),
          ),
        Expanded(child: _buildNearbyContent()),
      ],
    );
  }

  Widget _buildNearbyContent() {
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
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
          child: Text('No banners match the selected filter.'));
    }

    return ListView.separated(
      controller: _nearbyScrollController,
      itemCount: visible.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i == visible.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildBannerTile(visible[i]);
      },
    );
  }

  // ── To-do tab ──────────────────────────────────────────────────────────

  Widget _buildTodoTab() {
    if (_loadingTodo && _todoBanners.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_loadingTodo && _todoBanners.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _isSignedIn
                    ? 'No to-do banners on Bannergress.'
                    : 'No to-do banners yet.\nOpen a banner and mark it as "To-do".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (!_isSignedIn && widget._authService != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in to sync from Bannergress'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTodoBanners,
      child: ListView.separated(
        itemCount: _todoBanners.length + (_loadingTodo ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          if (i == _todoBanners.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildBannerTile(_todoBanners[i], showListBadge: false);
        },
      ),
    );
  }

  // ── Shared banner tile ─────────────────────────────────────────────────

  Widget _buildBannerTile(BannerItem banner, {bool showListBadge = true}) {
    final listType = showListBadge ? _listTypes[banner.id] : null;
    final distance = _formatDistance(banner);

    final subtitleParts = [
      if (banner.numberOfMissions != null)
        '${banner.numberOfMissions} mission'
        '${banner.numberOfMissions == 1 ? '' : 's'}',
      ?distance,
    ];

    return ListTile(
      onTap: () async {
        final updated = await Navigator.push<Map<String, String>>(
          context,
          MaterialPageRoute(
            builder: (_) => BannerDetailPage(
              banner: banner,
              bannerService: widget._bannerService,
              storageService: widget._storageService,
              listTypes: _listTypes,
            ),
          ),
        );
        if (updated != null) {
          setState(() => _listTypes = updated);
          await widget._storageService.saveListTypes(updated);
          if (_todoBanners.isNotEmpty || _tabController.index == 1) {
            _fetchTodoBanners();
          }
        }
      },
      leading: Hero(
        tag: 'banner-${banner.id}',
        child: GestureDetector(
          onTap: () => showFullImage(context, banner.pictureUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: banner.pictureUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const Icon(Icons.map, size: 48),
            ),
          ),
        ),
      ),
      title: Text(banner.title),
      subtitle: (subtitleParts.isNotEmpty || banner.warning != null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitleParts.isNotEmpty) Text(subtitleParts.join('  ·  ')),
                if (banner.warning != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        size: 12,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          banner.warning!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner.missions.any(
                (m) => m.steps.any((s) => s.objective == 'enterPassphrase'),
              ))
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.key_outlined, size: 16, color: Colors.amber),
            ),
          if (listType != null && listType != 'none')
            _ListTypeBadge(listType: listType),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

// ─── Bannergress sign-in banner ───────────────────────────────────────────────

class _BannergressSignInBanner extends StatelessWidget {
  const _BannergressSignInBanner({
    required this.authError,
    required this.onSignIn,
  });

  final String? authError;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final hasError = authError != null;
    final color = hasError ? Colors.red : Colors.blue;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              hasError ? Icons.error_outline : Icons.account_circle_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasError
                    ? authError!
                    : 'Sign in to sync your To-do list from Bannergress',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onSignIn,
              child: Text('Sign in', style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.hiddenFilters,
    required this.listTypes,
    required this.banners,
    required this.onChanged,
  });

  final Set<String> hiddenFilters;
  final Map<String, String> listTypes;
  final List<BannerItem> banners;
  final ValueChanged<Set<String>> onChanged;

  int _count(String key) {
    if (key == 'unsorted') {
      return banners.where((b) {
        final t = listTypes[b.id];
        return t == null || t == 'none';
      }).length;
    }
    return banners.where((b) => listTypes[b.id] == key).length;
  }

  @override
  Widget build(BuildContext context) {
    const options = [
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
          children: [
            if (hiddenFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.visibility_outlined, size: 15),
                  label:
                      const Text('Show all', style: TextStyle(fontSize: 12)),
                  onPressed: () => onChanged({}),
                ),
              ),
            ...options.map((opt) {
              final (key, label, icon, baseColor) = opt;
              final color = baseColor as Color;
              final visible = !hiddenFilters.contains(key);
              final count = _count(key);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  selected: visible,
                  avatar: Icon(icon,
                      size: 15, color: visible ? color : Colors.grey),
                  label: Text('$label  $count',
                      style: const TextStyle(fontSize: 12)),
                  onSelected: (_) {
                    final updated = Set<String>.of(hiddenFilters);
                    if (visible) {
                      updated.add(key);
                    } else {
                      updated.remove(key);
                    }
                    onChanged(updated);
                  },
                  selectedColor: color.withValues(alpha: 0.15),
                  checkmarkColor: color,
                  showCheckmark: false,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Location bar ────────────────────────────────────────────────────────────

class _LocationBar extends StatelessWidget {
  const _LocationBar({
    required this.position,
    required this.customCenter,
    required this.onPickLocation,
    required this.onClearCustom,
  });

  final Position? position;
  final LatLng? customCenter;
  final VoidCallback onPickLocation;
  final VoidCallback onClearCustom;

  @override
  Widget build(BuildContext context) {
    final isCustom = customCenter != null;
    final lat = isCustom ? customCenter!.latitude : position?.latitude;
    final lng = isCustom ? customCenter!.longitude : position?.longitude;
    final coordText = lat != null && lng != null
        ? '${lat.toStringAsFixed(5)},  ${lng.toStringAsFixed(5)}'
        : 'Locating…';

    return InkWell(
      onTap: onPickLocation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(
              isCustom ? Icons.location_pin : Icons.my_location,
              size: 16,
              color: isCustom
                  ? Colors.orange
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isCustom ? coordText : '$coordText  (GPS)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            if (isCustom)
              GestureDetector(
                onTap: onClearCustom,
                child: Tooltip(
                  message: 'Switch back to GPS',
                  child: Icon(Icons.gps_fixed,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              )
            else
              Icon(Icons.edit_location_alt_outlined,
                  size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
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
