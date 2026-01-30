import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/app_theme.dart';

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
                _buildSidebar(context),

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
              'ThirdBooks',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
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

  Widget _buildSidebar(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isCollapsed ? 70 : 240,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Company info section
          if (!_isCollapsed)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demo Company',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'FY 2024/2025',
                              style: TextStyle(
                                color: AppColors.sidebarTextMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
          _buildNavItem(
            context,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            path: '/settings',
            isActive: currentPath == '/settings',
          ),

          // Collapse button
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              icon: Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: AppColors.sidebarTextMuted,
              ),
              tooltip: _isCollapsed ? 'Expand' : 'Collapse',
            ),
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
