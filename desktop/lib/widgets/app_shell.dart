import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/app_theme.dart';
import '../core/services/auth_service.dart';
import '../core/widgets/sync_status_indicator.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      body: Column(
        children: [
          // Custom title bar for desktop
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            _buildTitleBar(context),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Sidebar
                _buildSidebar(context, user),

                // Main content area
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        color: AppColors.sidebarBackground,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Image.asset(
              'assets/images/logo_white.png',
              height: 20,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.account_balance,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'MagicBet Accounting',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 24),
            const SyncStatusIndicator(),
            const Spacer(),
            // Window controls
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, User? user) {
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isCollapsed ? 70 : 260,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // User profile section
          if (!_isCollapsed)
            _buildUserSection(user),

          const Divider(color: AppColors.sidebarItemHover, height: 1),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavSection('MAIN'),
                _buildNavItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  path: '/',
                  isActive: currentPath == '/',
                ),

                const SizedBox(height: 16),
                _buildNavSection('ACCOUNTING'),
                _buildNavItem(
                  context,
                  icon: Icons.account_tree_outlined,
                  activeIcon: Icons.account_tree,
                  label: 'Chart of Accounts',
                  path: '/accounts',
                  isActive: currentPath == '/accounts',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.book_outlined,
                  activeIcon: Icons.book,
                  label: 'Journal Entries',
                  path: '/journals',
                  isActive: currentPath == '/journals',
                ),

                const SizedBox(height: 16),
                _buildNavSection('SALES'),
                _buildNavItem(
                  context,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Customers',
                  path: '/customers',
                  isActive: currentPath == '/customers',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Invoices',
                  path: '/invoices',
                  isActive: currentPath == '/invoices',
                ),

                const SizedBox(height: 16),
                _buildNavSection('PURCHASES'),
                _buildNavItem(
                  context,
                  icon: Icons.store_outlined,
                  activeIcon: Icons.store,
                  label: 'Vendors',
                  path: '/vendors',
                  isActive: currentPath == '/vendors',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  label: 'Bills',
                  path: '/bills',
                  isActive: currentPath == '/bills',
                ),

                const SizedBox(height: 16),
                _buildNavSection('BANKING'),
                _buildNavItem(
                  context,
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  label: 'Payments',
                  path: '/payments',
                  isActive: currentPath == '/payments',
                ),

                const SizedBox(height: 16),
                _buildNavSection('OUTLETS'),
                _buildNavItem(
                  context,
                  icon: Icons.store_mall_directory_outlined,
                  activeIcon: Icons.store_mall_directory,
                  label: 'Outlets',
                  path: '/outlets',
                  isActive: currentPath == '/outlets',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.attach_money_outlined,
                  activeIcon: Icons.attach_money,
                  label: 'Revenue',
                  path: '/outlet-revenue',
                  isActive: currentPath == '/outlet-revenue',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.money_off_outlined,
                  activeIcon: Icons.money_off,
                  label: 'Expenditures',
                  path: '/outlet-expenditure',
                  isActive: currentPath == '/outlet-expenditure',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.payment_outlined,
                  activeIcon: Icons.payment,
                  label: 'Commissions',
                  path: '/commissions',
                  isActive: currentPath == '/commissions',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.cloud_upload_outlined,
                  activeIcon: Icons.cloud_upload,
                  label: 'Upload',
                  path: '/outlet-upload',
                  isActive: currentPath == '/outlet-upload',
                ),

                const SizedBox(height: 16),
                _buildNavSection('ASSETS'),
                _buildNavItem(
                  context,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'Assets',
                  path: '/assets',
                  isActive: currentPath == '/assets',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.trending_down_outlined,
                  activeIcon: Icons.trending_down,
                  label: 'Depreciation',
                  path: '/depreciation',
                  isActive: currentPath == '/depreciation',
                ),

                const SizedBox(height: 16),
                _buildNavSection('REPORTS'),
                _buildNavItem(
                  context,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics,
                  label: 'Reports',
                  path: '/reports',
                  isActive: currentPath == '/reports',
                ),
              ],
            ),
          ),

          // Bottom section
          const Divider(color: AppColors.sidebarItemHover, height: 1),

          // Settings
          _buildNavItem(
            context,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            path: '/settings',
            isActive: currentPath == '/settings',
          ),

          // Logout button
          _buildLogoutButton(context),

          // Collapse button and copyright
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '© 2026 Magic Bet Ltd',
                      style: TextStyle(
                        color: AppColors.sidebarTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  icon: Icon(
                    _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: AppColors.sidebarTextMuted,
                  ),
                  tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.secondary, AppColors.secondaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Guest User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Offline Mode',
                      style: TextStyle(
                        color: AppColors.sidebarTextMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  user?.role.replaceAll('_', ' ').toUpperCase() ?? 'GUEST',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.red.withOpacity(0.15),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 12,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Any unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              // Perform logout
              await ref.read(authStateProvider.notifier).logout();

              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                context.go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(String title) {
    if (_isCollapsed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.sidebarTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String path,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.sidebarItemHover,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarItemActive.withOpacity(0.15) : null,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border(
                      left: BorderSide(
                        color: AppColors.sidebarItemActive,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppColors.sidebarItemActive : AppColors.sidebarText,
                  size: 20,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? AppColors.sidebarItemActive : AppColors.sidebarText,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose ? Colors.red : Colors.white.withOpacity(0.1),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
