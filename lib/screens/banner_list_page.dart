import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/banner_item.dart';
import '../version.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/location_service.dart';
import '../utils/format.dart';
import 'location_picker_page.dart';
import '../widgets/banner_tile.dart';
import '../widgets/filter_bar.dart';
import '../widgets/location_bar.dart';
import '../widgets/sign_in_banner.dart';

class BannerListPage extends StatefulWidget {
  BannerListPage({
    super.key,
    LocationService? locationService,
    BannerService? bannerService,
    AuthService? authService,
    this.onToggleTheme,
    this.isDarkMode = true,
  })  : _locationService = locationService ?? const LocationService(),
        _bannerService = bannerService ?? BannerService(),
        _authService = authService;

  final LocationService _locationService;
  final BannerService _bannerService;
  final AuthService? _authService;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  @override
  State<BannerListPage> createState() => _BannerListPageState();
}

class _BannerListPageState extends State<BannerListPage>
    with SingleTickerProviderStateMixin {
  // ── Nearby tab state ───────────────────────────────────────────────────────
  List<BannerItem> _banners = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  double? _fetchLat;
  double? _fetchLng;
  String? _error;
  Set<String> _hiddenFilters = {};
  final ScrollController _nearbyScrollController = ScrollController();

  // ── To-do tab state ────────────────────────────────────────────────────────
  List<BannerItem> _todoBanners = [];
  bool _loadingTodo = false;
  bool _loadingMoreTodo = false;
  bool _todoHasMore = true;
  final ScrollController _todoScrollController = ScrollController();

  // ── Shared state ───────────────────────────────────────────────────────────
  Position? _position;
  LatLng? _customCenter;
  bool _isSignedIn = false;
  bool _checkingAuth = false;
  Map<String, String> _listTypes = {};
  String? _authError;
  late final TabController _tabController;

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
    _todoScrollController.addListener(_onTodoScroll);
    _fetchBanners();
    _checkAuth();
  }

  @override
  void dispose() {
    _nearbyScrollController.dispose();
    _todoScrollController.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_loadingTodo) _fetchTodoBanners();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> _checkAuth() async {
    final auth = widget._authService;
    if (auth == null) return;
    final loggedIn = await auth.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      setState(() => _isSignedIn = false);
      return;
    }
    final token = await _getToken();
    if (!mounted) return;
    setState(() => _isSignedIn = token != null);
    if (token != null) {
      unawaited(_syncListStates(token));
      if (_tabController.index == 1) _fetchTodoBanners();
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
      final token = await _getToken();
      if (token != null) unawaited(_syncListStates(token));
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
    if (!mounted) return;
    setState(() {
      _isSignedIn = false;
      _todoBanners = [];
      _listTypes = {};
      _hiddenFilters = {};
    });
    _fetchBanners();
  }

  // ── Nearby fetching ────────────────────────────────────────────────────────

  void _onNearbyScroll() {
    if (_nearbyScrollController.position.pixels >=
            _nearbyScrollController.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _fetchMoreBanners();
    }
  }

  void _onTodoScroll() {
    if (_todoScrollController.position.pixels >=
            _todoScrollController.position.maxScrollExtent - 300 &&
        !_loadingMoreTodo &&
        _todoHasMore &&
        !_loadingTodo) {
      _fetchMoreTodoBanners();
    }
  }

  Future<String?> _getToken() =>
      widget._authService?.getAccessToken() ?? Future.value(null);

  Future<void> _syncListStates(String token) async {
    try {
      final results = await Future.wait([
        widget._bannerService
            .fetchByListType(listType: 'todo', accessToken: token),
        widget._bannerService
            .fetchByListType(listType: 'done', accessToken: token),
        widget._bannerService
            .fetchByListType(listType: 'blacklist', accessToken: token),
      ]);
      final synced = <String, String>{};
      for (final (type, banners) in [
        ('todo', results[0]),
        ('done', results[1]),
        ('blacklist', results[2]),
      ]) {
        for (final b in banners) { synced[b.id] = type; }
      }
      if (mounted && synced.isNotEmpty) {
        setState(() => _listTypes = Map.of(_listTypes)..addAll(synced));
      }
    } catch (_) {}
  }

  void _mergeListTypes(List<BannerItem> banners) {
    final serverTypes = {
      for (final b in banners)
        if (b.listType != null && b.listType != 'none') b.id: b.listType!,
    };
    if (serverTypes.isEmpty) return;
    final merged = Map<String, String>.of(_listTypes)..addAll(serverTypes);
    if (mapEquals(merged, _listTypes)) return;
    setState(() => _listTypes = merged);
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
        final position =
            await widget._locationService.getCurrentPosition();
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
      if (token != null) _mergeListTypes(banners);
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
      if (token != null) _mergeListTypes(more);
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  // ── To-do fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchTodoBanners() async {
    if (_loadingTodo || !_isSignedIn) return;
    setState(() {
      _todoBanners = [];
      _todoHasMore = true;
      _loadingMoreTodo = false;
    });
    await _fetchTodosFromApi();
  }

  Future<void> _fetchMoreTodoBanners() async {
    if (_loadingMoreTodo || !_todoHasMore || !_isSignedIn) return;
    setState(() => _loadingMoreTodo = true);
    await _fetchTodosFromApi(offset: _todoBanners.length, append: true);
  }

  Future<void> _fetchTodosFromApi({int offset = 0, bool append = false}) async {
    final auth = widget._authService;
    if (auth == null) return;
    if (!append) setState(() => _loadingTodo = true);

    try {
      String? token = await auth.getAccessToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _loadingTodo = false;
            _loadingMoreTodo = false;
          });
        }
        return;
      }

      List<BannerItem> page;
      try {
        page = await widget._bannerService.fetchByListType(
          listType: 'todo',
          accessToken: token,
          offset: offset,
          limit: BannerService.pageSize,
        );
      } on SessionExpiredException {
        token = await auth.refreshIfNeeded();
        if (token == null) {
          if (mounted) {
            setState(() {
              _isSignedIn = false;
              _loadingTodo = false;
              _loadingMoreTodo = false;
            });
          }
          return;
        }
        page = await widget._bannerService.fetchByListType(
          listType: 'todo',
          accessToken: token,
          offset: offset,
          limit: BannerService.pageSize,
        );
      }

      final all = append ? [..._todoBanners, ...page] : page;

      if (_position != null) {
        all.sort((a, b) {
          final da = _distanceMeters(a);
          final db = _distanceMeters(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      }

      if (mounted) {
        setState(() {
          _todoBanners = all;
          _todoHasMore = page.length >= BannerService.pageSize;
          _loadingTodo = false;
          _loadingMoreTodo = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTodo = false;
          _loadingMoreTodo = false;
        });
      }
    }
  }

  // ── Location picker ────────────────────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────────

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
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                  widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
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
            LocationBar(
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
                  text: 'Nearby'
                      '${_banners.isNotEmpty ? ' (${_banners.length})' : ''}',
                ),
                Tab(
                  icon: const Icon(Icons.bookmark_outline),
                  text: 'To-do'
                      '${_todoBanners.isNotEmpty ? ' (${_todoBanners.length}${_todoHasMore ? '+' : ''})' : ''}',
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
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
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
          child: Text('Signed in to Bannergress',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
      onSelected: (v) {
        if (v == 'signout') _signOut();
      },
    );
  }

  // ── Nearby tab ─────────────────────────────────────────────────────────────

  Widget _buildNearbyTab() {
    return Column(
      children: [
        if (widget._authService != null && !_isSignedIn)
          BannergressSignInBanner(
            authError: _authError,
            onSignIn: _signIn,
          ),
        if (_isSignedIn && _banners.isNotEmpty)
          FilterBar(
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
        final banner = visible[i];
        return BannerTile(
          banner: banner,
          bannerService: widget._bannerService,
          listTypes: _listTypes,
          listType: _isSignedIn ? _listTypes[banner.id] : null,
          distance: _formatDistance(banner),
          isSignedIn: _isSignedIn,
          getToken: _isSignedIn ? _getToken : null,
          onListTypesUpdated: _isSignedIn
              ? (updated) {
                  setState(() => _listTypes = updated);
                  if (_todoBanners.isNotEmpty ||
                      _tabController.index == 1) {
                    _fetchTodoBanners();
                  }
                }
              : null,
        );
      },
    );
  }

  // ── To-do tab ──────────────────────────────────────────────────────────────

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
              const Icon(Icons.bookmark_border,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _isSignedIn
                    ? 'No to-do banners on Bannergress.'
                    : 'Sign in to see your Bannergress to-do list.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (!_isSignedIn && widget._authService != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
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
        controller: _todoScrollController,
        itemCount: _todoBanners.length + (_loadingMoreTodo ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          if (i == _todoBanners.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final banner = _todoBanners[i];
          return BannerTile(
            banner: banner,
            bannerService: widget._bannerService,
            listTypes: _listTypes,
            distance: _formatDistance(banner),
            isSignedIn: _isSignedIn,
            getToken: _isSignedIn ? _getToken : null,
            onListTypesUpdated: _isSignedIn
                ? (updated) {
                    setState(() => _listTypes = updated);
                    _fetchTodoBanners();
                  }
                : null,
          );
        },
      ),
    );
  }
}
