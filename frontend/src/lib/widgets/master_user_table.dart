import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_app/models/admin_user.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/theme/app_spacing.dart';

/// Master User Table for Admin Dashboard.
/// Displays: User Name, Email, Total Posts, Last Login.
/// Clickable rows to view user posts and comments.
class MasterUserTable extends StatefulWidget {
  final List<AdminUser> users;
  final bool loading;
  final String? error;
  final Function(AdminUser)? onUserTap;
  final Function(AdminUser)? onViewPosts;
  final Function(AdminUser)? onViewComments;
  final void Function(AdminUser)? onDeactivate;
  final void Function(AdminUser)? onActivate;
  final void Function(AdminUser)? onDelete;

  const MasterUserTable({
    super.key,
    required this.users,
    this.loading = false,
    this.error,
    this.onUserTap,
    this.onViewPosts,
    this.onViewComments,
    this.onDeactivate,
    this.onActivate,
    this.onDelete,
  });

  @override
  State<MasterUserTable> createState() => _MasterUserTableState();
}

class _MasterUserTableState extends State<MasterUserTable> {
  String _sortColumn = 'name';
  bool _sortAscending = true;

  void _sort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<AdminUser> get _sortedUsers {
    final sorted = List<AdminUser>.from(widget.users);
    sorted.sort((a, b) {
      int compare;
      switch (_sortColumn) {
        case 'name':
          compare = a.name.compareTo(b.name);
          break;
        case 'email':
          compare = a.email.compareTo(b.email);
          break;
        case 'totalPosts':
          compare = a.totalPosts.compareTo(b.totalPosts);
          break;
        case 'lastLogin':
          final aDate = a.lastLogin ?? '';
          final bDate = b.lastLogin ?? '';
          compare = aDate.compareTo(bDate);
          break;
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  String _formatLastLogin(String? lastLogin) {
    if (lastLogin == null || lastLogin.isEmpty) return 'Never';
    try {
      final date = DateTime.parse(lastLogin);
      return timeago.format(date);
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryGreen),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            widget.error!,
            style: const TextStyle(color: kAccentOrange),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No users found',
            style: TextStyle(color: kCaptionGray),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: ['name', 'email', 'totalPosts', 'lastLogin'].indexOf(_sortColumn),
        sortAscending: _sortAscending,
        headingRowColor: WidgetStateProperty.all(kSurfaceWarmGray.withOpacity(0.5)),
        columns: [
          DataColumn(
            label: const Text('User Name', style: TextStyle(fontWeight: FontWeight.bold)),
            onSort: (_, __) => _sort('name'),
          ),
          DataColumn(
            label: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
            onSort: (_, __) => _sort('email'),
          ),
          DataColumn(
            numeric: true,
            label: const Text('Total Posts', style: TextStyle(fontWeight: FontWeight.bold)),
            onSort: (_, __) => _sort('totalPosts'),
          ),
          DataColumn(
            label: const Text('Last Login', style: TextStyle(fontWeight: FontWeight.bold)),
            onSort: (_, __) => _sort('lastLogin'),
          ),
          const DataColumn(
            label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        rows: _sortedUsers.map((user) {
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return kPrimaryGreen.withOpacity(0.05);
              }
              return null;
            }),
            onSelectChanged: (_) => widget.onUserTap?.call(user),
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: kPrimaryGreen.withOpacity(0.1),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: kPrimaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(user.name),
                  ],
                ),
                onTap: () => widget.onUserTap?.call(user),
              ),
              DataCell(
                Text(user.email),
                onTap: () => widget.onUserTap?.call(user),
              ),
              DataCell(
                Text(user.totalPosts.toString()),
                onTap: () => widget.onUserTap?.call(user),
              ),
              DataCell(
                Text(_formatLastLogin(user.lastLogin)),
                onTap: () => widget.onUserTap?.call(user),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => widget.onViewPosts?.call(user),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: const Text('Posts'),
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onViewComments?.call(user),
                      icon: const Icon(Icons.comment_outlined, size: 16),
                      label: const Text('Comments'),
                      style: TextButton.styleFrom(
                        foregroundColor: kAccentOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    if (widget.onDeactivate != null || widget.onActivate != null || widget.onDelete != null)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        itemBuilder: (context) => [
                          if (user.isActive && widget.onDeactivate != null)
                            const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                          if (!user.isActive && widget.onActivate != null)
                            const PopupMenuItem(value: 'activate', child: Text('Activate')),
                          if (widget.onDelete != null)
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (value) {
                          if (value == 'deactivate') {
                            widget.onDeactivate?.call(user);
                          } else if (value == 'activate') {
                            widget.onActivate?.call(user);
                          } else if (value == 'delete') {
                            widget.onDelete?.call(user);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}