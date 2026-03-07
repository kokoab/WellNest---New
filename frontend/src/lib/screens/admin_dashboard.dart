import 'package:flutter/material.dart';
import 'package:my_app/models/admin_user.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';
import 'package:my_app/services/admin_auth_service.dart';
import 'package:my_app/services/admin_user_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUsers();
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

  List<AdminUser> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      return u.email.toLowerCase().contains(q) || u.name.toLowerCase().contains(q);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
          content: Text(status == 'active' ? 'Account activated' : 'Account deactivated'),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        const SnackBar(content: Text('Account deleted'), backgroundColor: wellGreen),
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
          onRefresh: _loadUsers,
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
                          child: const Icon(Icons.notifications, color: nestOrange, size: 28),
                        ),
                        IconButton(
                          onPressed: () async {
                        await AdminAuthService.instance.logoutAdmin();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, '/admin_login', (r) => false);
                          },
                          icon: const Icon(Icons.logout, color: nestOrange, size: 28),
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
                        borderSide: const BorderSide(color: accentYellow, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: nestOrange, width: 2),
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
                      child: _buildModernStatCard("Recipes", "34", Icons.restaurant_menu_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Manage Users',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: wellGreen,
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: wellGreen, strokeWidth: 2),
                            )
                          else
                            IconButton(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh_rounded, color: wellGreen),
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
                                style: FilledButton.styleFrom(backgroundColor: wellGreen),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchQuery.isEmpty ? 'No users yet' : 'No users match your search',
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
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

  Widget _buildModernStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: lightGrey),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: nestOrange, size: 30),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: wellGreen),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
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
                  (user.name.isNotEmpty ? user.name[0] : user.email.isNotEmpty ? user.email[0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(color: wellGreen, fontWeight: FontWeight.bold),
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
                  icon: const Icon(Icons.person_off, size: 18, color: nestOrange),
                  label: const Text('Deactivate', style: TextStyle(color: nestOrange)),
                )
              else
                TextButton.icon(
                  onPressed: () => onActivate(user),
                  icon: const Icon(Icons.person_add, size: 18, color: wellGreen),
                  label: const Text('Activate', style: TextStyle(color: wellGreen)),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => onDelete(user),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        color: isActive ? wellGreen.withOpacity(0.15) : Colors.orange.withOpacity(0.2),
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
