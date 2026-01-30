import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/journals/journals_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/vendors/vendors_screen.dart';
import '../../features/bills/bills_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Main app shell with sidebar navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/journals',
            name: 'journals',
            builder: (context, state) => const JournalsScreen(),
          ),
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/invoices',
            name: 'invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/vendors',
            name: 'vendors',
            builder: (context, state) => const VendorsScreen(),
          ),
          GoRoute(
            path: '/bills',
            name: 'bills',
            builder: (context, state) => const BillsScreen(),
          ),
          GoRoute(
            path: '/payments',
            name: 'payments',
            builder: (context, state) => const PaymentsScreen(),
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
        ],
      ),
    ],
  );
});
