import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/conflicts/conflicts_screen.dart';
import '../../features/sync/sync_status_screen.dart';
import '../../features/accounts/accounts_list_screen.dart';
import '../../features/customers/customers_list_screen.dart';
import '../../features/vendors/vendors_list_screen.dart';
import '../../features/invoices/invoices_list_screen.dart';
import '../../features/bills/bills_list_screen.dart';
import '../../features/journals/journal_entries_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';

// Navigation shell with bottom navigation
class MainShell extends StatefulWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _calculateSelectedIndex() {
    final location = widget.location;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/sales') || location.startsWith('/invoices') || location.startsWith('/customers')) return 1;
    if (location.startsWith('/purchases') || location.startsWith('/bills') || location.startsWith('/vendors')) return 2;
    if (location.startsWith('/accounting') || location.startsWith('/accounts') || location.startsWith('/journals')) return 3;
    if (location.startsWith('/more') || location.startsWith('/reports') || location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex();
    final theme = Theme.of(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/sales');
              break;
            case 2:
              context.go('/purchases');
              break;
            case 3:
              context.go('/accounting');
              break;
            case 4:
              context.go('/more');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Purchases',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Accounting',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

// Sales Menu Screen
class SalesMenuScreen extends StatelessWidget {
  const SalesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: ListView(
        children: [
          _MenuTile(
            icon: Icons.people,
            title: 'Customers',
            subtitle: 'Manage your customers',
            onTap: () => context.go('/customers'),
          ),
          _MenuTile(
            icon: Icons.receipt_long,
            title: 'Invoices',
            subtitle: 'Create and manage invoices',
            onTap: () => context.go('/invoices'),
          ),
          _MenuTile(
            icon: Icons.payments,
            title: 'Payments Received',
            subtitle: 'Record customer payments',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payments feature coming soon')),
            ),
          ),
          _MenuTile(
            icon: Icons.bar_chart,
            title: 'Sales Reports',
            subtitle: 'View sales analytics',
            onTap: () => context.go('/reports'),
          ),
        ],
      ),
    );
  }
}

// Purchases Menu Screen
class PurchasesMenuScreen extends StatelessWidget {
  const PurchasesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      body: ListView(
        children: [
          _MenuTile(
            icon: Icons.business,
            title: 'Vendors',
            subtitle: 'Manage your suppliers',
            onTap: () => context.go('/vendors'),
          ),
          _MenuTile(
            icon: Icons.receipt,
            title: 'Bills',
            subtitle: 'Record and track bills',
            onTap: () => context.go('/bills'),
          ),
          _MenuTile(
            icon: Icons.payments,
            title: 'Payments Made',
            subtitle: 'Record vendor payments',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payments feature coming soon')),
            ),
          ),
          _MenuTile(
            icon: Icons.bar_chart,
            title: 'Purchase Reports',
            subtitle: 'View expense analytics',
            onTap: () => context.go('/reports'),
          ),
        ],
      ),
    );
  }
}

// Accounting Menu Screen
class AccountingMenuScreen extends StatelessWidget {
  const AccountingMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounting')),
      body: ListView(
        children: [
          _MenuTile(
            icon: Icons.account_tree,
            title: 'Chart of Accounts',
            subtitle: 'Manage your accounts',
            onTap: () => context.go('/accounts'),
          ),
          _MenuTile(
            icon: Icons.book,
            title: 'Journal Entries',
            subtitle: 'Manual journal entries',
            onTap: () => context.go('/journals'),
          ),
          _MenuTile(
            icon: Icons.receipt_long,
            title: 'General Ledger',
            subtitle: 'View all transactions',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('General Ledger coming soon')),
            ),
          ),
          _MenuTile(
            icon: Icons.bar_chart,
            title: 'Financial Reports',
            subtitle: 'Trial balance, P&L, Balance Sheet',
            onTap: () => context.go('/reports'),
          ),
        ],
      ),
    );
  }
}

// More Menu Screen
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _MenuTile(
            icon: Icons.assessment,
            title: 'Reports',
            subtitle: 'All financial reports',
            onTap: () => context.go('/reports'),
          ),
          _MenuTile(
            icon: Icons.sync,
            title: 'Sync Status',
            subtitle: 'Check synchronization status',
            onTap: () => context.go('/sync-status'),
          ),
          _MenuTile(
            icon: Icons.warning,
            title: 'Conflicts',
            subtitle: 'Resolve sync conflicts',
            onTap: () => context.go('/conflicts'),
          ),
          const Divider(),
          _MenuTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences',
            onTap: () => context.go('/settings'),
          ),
          _MenuTile(
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help with the app',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help feature coming soon')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Router Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Login (no shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Main app with shell
      ShellRoute(
        builder: (context, state, child) => MainShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // Sales Section
          GoRoute(
            path: '/sales',
            name: 'sales',
            builder: (context, state) => const SalesMenuScreen(),
          ),
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) => const CustomersListScreen(),
          ),
          GoRoute(
            path: '/invoices',
            name: 'invoices',
            builder: (context, state) => const InvoicesListScreen(),
          ),

          // Purchases Section
          GoRoute(
            path: '/purchases',
            name: 'purchases',
            builder: (context, state) => const PurchasesMenuScreen(),
          ),
          GoRoute(
            path: '/vendors',
            name: 'vendors',
            builder: (context, state) => const VendorsListScreen(),
          ),
          GoRoute(
            path: '/bills',
            name: 'bills',
            builder: (context, state) => const BillsListScreen(),
          ),

          // Accounting Section
          GoRoute(
            path: '/accounting',
            name: 'accounting',
            builder: (context, state) => const AccountingMenuScreen(),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsListScreen(),
          ),
          GoRoute(
            path: '/journals',
            name: 'journals',
            builder: (context, state) => const JournalEntriesScreen(),
          ),

          // More Section
          GoRoute(
            path: '/more',
            name: 'more',
            builder: (context, state) => const MoreMenuScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/sync-status',
            name: 'sync-status',
            builder: (context, state) => const SyncStatusScreen(),
          ),
          GoRoute(
            path: '/conflicts',
            name: 'conflicts',
            builder: (context, state) => const ConflictsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});
