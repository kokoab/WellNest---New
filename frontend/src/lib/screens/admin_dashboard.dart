import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:my_app/models/activity_log.dart';
import 'package:my_app/models/admin_user.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/report.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/admin_user_service.dart';
import 'package:my_app/services/admin_moderation_service.dart';
import 'package:my_app/services/admin_activity_log_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/category_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Brand Colors
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);
  static const Color lightGrey = Color(0xFFF5F5F5);

  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  List<Report> _reports = [];
  bool _reportsLoading = true;
  String? _reportsError;

  int _recipeTotal = 0;
  bool _recipeTotalLoading = true;

  List<ActivityLog> _activityLogs = [];
  bool _logsLoading = true;
  String? _logsError;
  bool _exportingReportsCsv = false;
  bool _exportingInsightsCsv = false;
  bool _exportingUsersCsv = false;
  List<Category> _categories = [];
  bool _categoriesLoading = true;
  String? _categoriesError;

  @override
  void initState() {
    super.initState();
    // If admin role is not present (e.g. after hot restart or user login),
    // send them back to the normal login instead of hammering the API.
    if (!AuthService.instance.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      });
      return;
    }
    _loadUsers();
    _loadReports();
    _loadRecipeTotal();
    _loadActivityLogs();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final list = await CategoryService.instance.fetchCategories(admin: true);
      if (!mounted) return;
      setState(() {
        _categories = list;
        _categoriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = e.toString().replaceFirst('Exception: ', '');
        _categoriesLoading = false;
      });
    }
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
    });
    try {
      final list = await AdminModerationService.instance.fetchReports();
      if (!mounted) return;
      setState(() {
        _reports = list;
        _reportsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsError = e.toString().replaceFirst('Exception: ', '');
        _reportsLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AdminUserService.instance.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadRecipeTotal() async {
    if (!mounted) return;
    setState(() => _recipeTotalLoading = true);
    try {
      final res = await RecipeService.instance.fetchRecipes(page: 1);
      if (!mounted) return;
      setState(() {
        _recipeTotal = res.total;
        _recipeTotalLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recipeTotalLoading = false);
    }
  }

  Future<void> _loadActivityLogs() async {
    if (!mounted) return;
    setState(() {
      _logsLoading = true;
      _logsError = null;
    });
    try {
      final res = await AdminActivityLogService.instance.fetchLogs(page: 1);
      if (!mounted) return;
      setState(() {
        _activityLogs = res.logs;
        _logsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logsError = e.toString().replaceFirst('Exception: ', '');
        _logsLoading = false;
      });
    }
  }

  String _escapeCsv(String? s) {
    if (s == null || s.isEmpty) return '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _exportReportsCsv() async {
    if (_exportingReportsCsv) return;
    setState(() => _exportingReportsCsv = true);
    try {
      final rows = <String>[
        'id,reporter,reason,details,status,created_at,reportable_type,reportable_id,reportable_label',
      ];
      for (final r in _reports) {
        final type = r.reportable?.type ?? '';
        final id = r.reportable?.id ?? 0;
        final label = r.reportableLabel
            .replaceAll(',', ' ')
            .replaceAll('\n', ' ');
        rows.add(
          [
            r.id,
            _escapeCsv(r.reporter),
            _escapeCsv(r.reason),
            _escapeCsv(r.details),
            _escapeCsv(r.status),
            _escapeCsv(r.createdAt),
            _escapeCsv(type),
            id,
            _escapeCsv(label),
          ].join(','),
        );
      }
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'content_reports_export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles(
        [xfile],
        subject: 'WellNest Content Reports Export',
        text: 'Content moderation reports CSV export',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reports exported'),
          backgroundColor: wellGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingReportsCsv = false);
    }
  }

  Future<void> _exportInsightsCsv() async {
    if (_exportingInsightsCsv) return;
    setState(() => _exportingInsightsCsv = true);
    try {
      final totalUsers = _users.length;
      final activeUsers = _users.where((u) => u.isActive).length;
      final totalRecipes = _recipeTotal;

      // Fetch multiple pages of recipes to find most popular (by ratings_count)
      final allRecipes = <Recipe>[];
      for (var page = 1; page <= 5; page++) {
        final res = await RecipeService.instance.fetchRecipes(page: page);
        allRecipes.addAll(res.recipes);
        if (res.recipes.length < 10) break;
      }
      allRecipes.sort((a, b) {
        final aCount = a.ratingsCount ?? 0;
        final bCount = b.ratingsCount ?? 0;
        if (aCount != bCount) return bCount.compareTo(aCount);
        final aRate = a.averageRating ?? 0;
        final bRate = b.averageRating ?? 0;
        return bRate.compareTo(aRate);
      });
      final topRecipes = allRecipes.take(25).toList();

      final rows = <String>[
        'Metric,Value',
        'Total Users,$totalUsers',
        'Active Users,$activeUsers',
        'Total Recipes,$totalRecipes',
        '',
        'Most Popular Recipes',
        'rank,id,title,category,average_rating,ratings_count',
      ];
      for (var i = 0; i < topRecipes.length; i++) {
        final r = topRecipes[i];
        final cat = r.category?.name ?? '';
        final avg = r.averageRating?.toStringAsFixed(1) ?? '0';
        final cnt = r.ratingsCount ?? 0;
        rows.add(
          '${i + 1},${r.id},${_escapeCsv(r.title)},${_escapeCsv(cat)},$avg,$cnt',
        );
      }
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'admin_insights_export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles(
        [xfile],
        subject: 'WellNest Admin Insights Report',
        text: 'Total users, recipes, active users, and most popular recipes',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insights report exported'),
          backgroundColor: wellGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingInsightsCsv = false);
    }
  }

  Future<void> _exportUsersCsv() async {
    if (_exportingUsersCsv) return;
    setState(() => _exportingUsersCsv = true);
    try {
      final rows = <String>['id,name,email,status'];
      for (final u in _users) {
        rows.add(
          '${u.id},${_escapeCsv(u.name)},${_escapeCsv(u.email)},${_escapeCsv(u.status)}',
        );
      }
      final csv = rows.join('\n');
      final bytes = Uint8List.fromList(csv.codeUnits);
      final xfile = XFile.fromData(
        bytes,
        name: 'users_export.csv',
        mimeType: 'text/csv',
      );
      await Share.shareXFiles(
        [xfile],
        subject: 'WellNest Users Export',
        text: 'Registered users list',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Users exported'),
          backgroundColor: wellGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingUsersCsv = false);
    }
  }

  List<AdminUser> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      return u.email.toLowerCase().contains(q) ||
          u.name.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDeactivate(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text(
          'Deactivate "${user.name}" (${user.email})? They will not be able to sign in until reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: nestOrange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _updateStatus(user.id, 'inactive');
  }

  Future<void> _confirmActivate(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate account?'),
        content: Text(
          'Reactivate "${user.name}" (${user.email})? They will be able to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: wellGreen),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _updateStatus(user.id, 'active');
  }

  Future<void> _updateStatus(int userId, String status) async {
    try {
      await AdminUserService.instance.updateUserStatus(userId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'active' ? 'Account activated' : 'Account deactivated',
          ),
          backgroundColor: wellGreen,
        ),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: Text(
          'Permanently delete "${user.name}" (${user.email})? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _deleteUser(user.id);
  }

  Future<void> _deleteUser(int userId) async {
    try {
      await AdminUserService.instance.deleteUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted'),
          backgroundColor: wellGreen,
        ),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUsers();
            await _loadReports();
            await _loadRecipeTotal();
            await _loadActivityLogs();
          },
          color: wellGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- APP BAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconButton(Icons.grid_view_rounded),
                    Image.asset('lib/assets/images/logo1.png', height: 45),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NotificationsDropdown(
                          iconColor: nestOrange,
                          child: const Icon(
                            Icons.notifications,
                            color: nestOrange,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await AuthService.instance.logout();
                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (r) => false,
                            );
                          },
                          icon: const Icon(
                            Icons.logout,
                            color: nestOrange,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // --- WELCOME TEXT ---
                const Text(
                  "Admin Console",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: wellGreen,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  "Manage your WellNest community",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                // --- SEARCH BAR (filter users) ---
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: accentYellow.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "Search by name or email...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: wellGreen),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: accentYellow,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: nestOrange,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // --- STATISTICS ---
                Row(
                  children: [
                    Expanded(
                      child: _buildModernStatCard(
                        "Users",
                        _loading ? '…' : '${_users.length}',
                        Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildModernStatCard(
                        "Active",
                        _loading
                            ? '…'
                            : '${_users.where((u) => u.isActive).length}',
                        Icons.person_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernStatCard(
                        "Recipes",
                        _recipeTotalLoading ? '…' : '$_recipeTotal',
                        Icons.restaurant_menu_rounded,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildModernStatCard(
                        "Reports",
                        _reportsLoading ? '…' : '${_reports.length}',
                        Icons.flag_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _exportingInsightsCsv ? null : _exportInsightsCsv,
                  style: FilledButton.styleFrom(
                    backgroundColor: wellGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: _exportingInsightsCsv
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 22),
                  label: Text(
                    _exportingInsightsCsv
                        ? 'Exporting…'
                        : 'Export Insights (Users, Recipes, Popular)',
                  ),
                ),
                const SizedBox(height: 25),
                // --- ACTIVITY LOGS & EXPORT ---
                _buildActivityLogsSection(),
                const SizedBox(height: 25),
                // --- MANAGE USERS SECTION ---
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: accentYellow,
                    borderRadius: BorderRadius.circular(35),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentYellow, accentYellow.withOpacity(0.8)],
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Manage Users',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: wellGreen,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_loading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: wellGreen,
                                strokeWidth: 2,
                              ),
                            )
                          else
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _loadUsers,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: wellGreen,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _exportingUsersCsv
                                        ? null
                                        : _exportUsersCsv,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: wellGreen,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: _exportingUsersCsv
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.download_rounded,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _exportingUsersCsv
                                          ? 'Exporting…'
                                          : 'Export CSV',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_loading && _users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: wellGreen),
                          ),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: nestOrange),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadUsers,
                                style: FilledButton.styleFrom(
                                  backgroundColor: wellGreen,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No users yet'
                                : 'No users match your search',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        ..._filteredUsers.map(
                          (user) => _UserTile(
                            user: user,
                            onDeactivate: _confirmDeactivate,
                            onActivate: _confirmActivate,
                            onDelete: _confirmDelete,
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                // --- CATEGORY MANAGEMENT SECTION ---
                _buildCategoriesSection(),
                const SizedBox(height: 25),
                // --- CONTENT MODERATION SECTION ---
                _buildModerationSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: nestOrange, size: 28),
    );
  }

  Widget _buildModerationSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentYellow,
        borderRadius: BorderRadius.circular(35),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentYellow, accentYellow.withOpacity(0.8)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Content Moderation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: wellGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_reportsLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: wellGreen,
                    strokeWidth: 2,
                  ),
                )
              else
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _loadReports,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: wellGreen,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _exportingReportsCsv
                            ? null
                            : _exportReportsCsv,
                        style: FilledButton.styleFrom(
                          backgroundColor: wellGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        icon: _exportingReportsCsv
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _exportingReportsCsv ? 'Exporting…' : 'Export CSV',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_reports.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _confirmDeleteAllReports,
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            color: nestOrange,
                            size: 24,
                          ),
                          tooltip: 'Delete all reports',
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_reportsLoading && _reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: wellGreen)),
            )
          else if (_reportsError != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _reportsError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: nestOrange),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadReports,
                    style: FilledButton.styleFrom(backgroundColor: wellGreen),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_reports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No pending reports',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            ..._reports.map(
              (r) => _ReportTile(
                report: r,
                onDismiss: () => _handleReportAction(r.id, 'dismiss'),
                onApprove: () => _handleReportAction(r.id, 'approve'),
                onRemoveContent: r.isRecipeReport || r.isPostReport
                    ? () => _handleReportAction(r.id, 'remove-content')
                    : null,
                onSuspendUser: r.isUserReport
                    ? () => _handleReportAction(r.id, 'suspend-user')
                    : null,
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentYellow,
        borderRadius: BorderRadius.circular(35),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentYellow, accentYellow.withOpacity(0.8)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: wellGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_categoriesLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: wellGreen,
                    strokeWidth: 2,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh_rounded, color: wellGreen),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showCategoryFormDialog(),
                      style: FilledButton.styleFrom(
                        backgroundColor: wellGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_categoriesLoading && _categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: wellGreen)),
            )
          else if (_categoriesError != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _categoriesError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: nestOrange),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadCategories,
                    style: FilledButton.styleFrom(backgroundColor: wellGreen),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No categories yet. Add one to get started.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            ..._categories.map(
              (c) => _CategoryTile(
                category: c,
                onEdit: () => _showCategoryFormDialog(existing: c),
                onDelete: () => _confirmDeleteCategory(c),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete category "${category.name}"? This will remove it from the list for new recipes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CategoryService.instance.deleteCategory(category.id);
      await _loadCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category deleted'),
          backgroundColor: wellGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Future<void> _showCategoryFormDialog({Category? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: wellGreen),
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final name = nameController.text.trim();
    final desc = descController.text.trim();
    if (name.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and description are required'),
          backgroundColor: nestOrange,
        ),
      );
      return;
    }
    try {
      if (existing == null) {
        await CategoryService.instance.createCategory(name, desc);
      } else {
        await CategoryService.instance.updateCategory(existing.id, name, desc);
      }
      await _loadCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Category created' : 'Category updated',
          ),
          backgroundColor: wellGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Widget _buildActivityLogsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentYellow,
        borderRadius: BorderRadius.circular(35),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentYellow, accentYellow.withOpacity(0.8)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Activity Logs & Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: wellGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_logsLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: wellGreen,
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  onPressed: _loadActivityLogs,
                  icon: const Icon(Icons.refresh_rounded, color: wellGreen),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recent activity (login, moderation, content).',
            style: TextStyle(fontSize: 13, color: wellGreen.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),
          if (_logsLoading && _activityLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: wellGreen)),
            )
          else if (_logsError != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _logsError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: nestOrange),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadActivityLogs,
                    style: FilledButton.styleFrom(backgroundColor: wellGreen),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_activityLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No activity logs yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            ..._activityLogs
                .take(15)
                .map(
                  (log) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lightGrey),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: nestOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${log.category} · ${log.action}${log.actorName != null ? ' · ${log.actorName}' : ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (log.createdAt != null)
                                Text(
                                  log.createdAt!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllReports() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all reports?'),
        content: const Text(
          'Permanently delete all pending reports? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AdminModerationService.instance.deleteAllReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All reports deleted'),
          backgroundColor: wellGreen,
        ),
      );
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Future<void> _handleReportAction(int reportId, String action) async {
    try {
      switch (action) {
        case 'dismiss':
          await AdminModerationService.instance.dismiss(reportId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report dismissed'),
              backgroundColor: wellGreen,
            ),
          );
          break;
        case 'approve':
          await AdminModerationService.instance.approve(reportId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report approved'),
              backgroundColor: wellGreen,
            ),
          );
          break;
        case 'remove-content':
          await AdminModerationService.instance.removeContent(reportId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content removed'),
              backgroundColor: wellGreen,
            ),
          );
          break;
        case 'suspend-user':
          await AdminModerationService.instance.suspendUser(reportId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User suspended'),
              backgroundColor: wellGreen,
            ),
          );
          break;
      }
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Widget _buildModernStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: lightGrey),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: nestOrange, size: 30),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: wellGreen,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final void Function(AdminUser) onDeactivate;
  final void Function(AdminUser) onActivate;
  final void Function(AdminUser) onDelete;

  const _UserTile({
    required this.user,
    required this.onDeactivate,
    required this.onActivate,
    required this.onDelete,
  });

  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: wellGreen.withOpacity(0.2),
                child: Text(
                  (user.name.isNotEmpty
                          ? user.name[0]
                          : user.email.isNotEmpty
                          ? user.email[0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: wellGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? 'No name' : user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StatusChip(isActive: user.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (user.isActive)
                TextButton.icon(
                  onPressed: () => onDeactivate(user),
                  icon: const Icon(
                    Icons.person_off,
                    size: 18,
                    color: nestOrange,
                  ),
                  label: const Text(
                    'Deactivate',
                    style: TextStyle(color: nestOrange),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => onActivate(user),
                  icon: const Icon(
                    Icons.person_add,
                    size: 18,
                    color: wellGreen,
                  ),
                  label: const Text(
                    'Activate',
                    style: TextStyle(color: wellGreen),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => onDelete(user),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Report report;
  final VoidCallback onDismiss;
  final VoidCallback onApprove;
  final VoidCallback? onRemoveContent;
  final VoidCallback? onSuspendUser;

  const _ReportTile({
    required this.report,
    required this.onDismiss,
    required this.onApprove,
    this.onRemoveContent,
    this.onSuspendUser,
  });

  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                report.isUserReport
                    ? Icons.person
                    : report.isRecipeReport
                    ? Icons.restaurant_menu
                    : Icons.article,
                color: nestOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportableLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (report.reporter != null)
                      Text(
                        'Reported by ${report.reporter}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    if (report.reason != null && report.reason!.isNotEmpty)
                      Text(
                        'Reason: ${report.reason}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    if (report.details != null && report.details!.isNotEmpty)
                      Text(
                        report.details!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: wellGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.reportable?.type ?? 'unknown',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: wellGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                label: const Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: onApprove,
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: wellGreen,
                ),
                label: const Text(
                  'Approve',
                  style: TextStyle(color: wellGreen),
                ),
              ),
              if (onRemoveContent != null)
                TextButton.icon(
                  onPressed: onRemoveContent,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: nestOrange,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: nestOrange),
                  ),
                ),
              if (onSuspendUser != null)
                TextButton.icon(
                  onPressed: onSuspendUser,
                  icon: const Icon(Icons.block, size: 16, color: Colors.red),
                  label: const Text(
                    'Suspend',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  static const Color wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? wellGreen.withOpacity(0.15)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Deactivated',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? wellGreen : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: wellGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.category_rounded,
              color: wellGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: wellGreen),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
