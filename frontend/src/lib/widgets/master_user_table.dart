import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:wellnest/models/admin_user.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/theme/app_spacing.dart';

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

  const MasterUserTable({
    super.key,
    required this.users,
    this.loading = false,
    this.error,
    this.onUserTap,
    this.onViewPosts,
    this.onViewComments,
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

  // Calculate responsive column width based on screen percentage
  double _getResponsiveColumnWidth(BuildContext context, double percentage) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Subtracts some padding to account for margins
    return (screenWidth * percentage) - 10;
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
          child: Text('No users found', style: TextStyle(color: kCaptionGray)),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          sortColumnIndex: [
            'name',
            'email',
            'totalPosts',
            'lastLogin',
          ].indexOf(_sortColumn),
          sortAscending: _sortAscending,
          columnSpacing: 12.0,
          headingRowColor: WidgetStateProperty.all(
            kSurfaceWarmGray.withOpacity(0.5),
          ),
          columns: [
            // Column 1: User Name (20% of screen width)
            DataColumn(
              label: SizedBox(
                width: _getResponsiveColumnWidth(context, 0.20),
                child: const Text(
                  'User Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onSort: (_, __) => _sort('name'),
            ),
            // Column 2: Email (25% of screen width)
            DataColumn(
              label: SizedBox(
                width: _getResponsiveColumnWidth(context, 0.25),
                child: const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onSort: (_, __) => _sort('email'),
            ),
            // Column 3: Total Posts (15% of screen width)
            DataColumn(
              numeric: true,
              label: SizedBox(
                width: _getResponsiveColumnWidth(context, 0.15),
                child: const Text(
                  'Total Posts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onSort: (_, __) => _sort('totalPosts'),
            ),
            // Column 4: Last Login (15% of screen width)
            DataColumn(
              label: SizedBox(
                width: _getResponsiveColumnWidth(context, 0.15),
                child: const Text(
                  'Last Login',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onSort: (_, __) => _sort('lastLogin'),
            ),
            // Column 5: Actions (25% of screen width)
            DataColumn(
              label: SizedBox(
                width: _getResponsiveColumnWidth(context, 0.25),
                child: const Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
              cells: [
                DataCell(
                  SizedBox(
                    width: _getResponsiveColumnWidth(context, 0.20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kPrimaryGreen.withOpacity(0.1),
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: kPrimaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => widget.onUserTap?.call(user),
                ),
                DataCell(
                  Tooltip(
                    message: user.email,
                    child: SizedBox(
                      width: _getResponsiveColumnWidth(context, 0.25),
                      child: Text(user.email, overflow: TextOverflow.ellipsis),
                    ),
                  ),
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
                  SizedBox(
                    width: _getResponsiveColumnWidth(context, 0.25),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () => widget.onViewPosts?.call(user),
                            icon: const Icon(Icons.article_outlined, size: 16),
                            label: const Text('Posts'),
                            style: TextButton.styleFrom(
                              foregroundColor: kPrimaryGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () => widget.onViewComments?.call(user),
                            icon: const Icon(Icons.comment_outlined, size: 16),
                            label: const Text('Comments'),
                            style: TextButton.styleFrom(
                              foregroundColor: kAccentOrange,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
