import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _loadingOpacity;

  String _statusMessage = 'Initializing...';
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSplashSequence();
  }

  void _initAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Loading animation controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.easeIn,
      ),
    );
  }

  Future<void> _startSplashSequence() async {
    // Record start time to ensure minimum 3 second display
    final startTime = DateTime.now();

    // Start logo animation
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));

    // Start text animation
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    // Show loading indicator
    _loadingController.forward();

    // Check authentication and API connectivity
    await _checkSystemStatus(startTime);
  }

  Future<void> _checkSystemStatus(DateTime startTime) async {
    setState(() {
      _statusMessage = 'Loading...';
      _isConnecting = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = await authService.isAuthenticated();

      if (isAuthenticated) {
        setState(() => _statusMessage = 'Restoring session...');
        await Future.delayed(const Duration(milliseconds: 500));

        // For offline-session tokens (local users: Marion, Allan) skip the
        // server round-trip entirely — they will never have a valid Sanctum
        // token, so validateToken() always returns false and would redirect
        // them to the login screen on every launch.
        final token = await authService.getToken() ?? '';
        final isOfflineSession = token.startsWith('offline-session-');

        bool isValid = isOfflineSession;
        if (!isOfflineSession) {
          isValid = await authService.validateToken();
        }

        if (isValid && mounted) {
          setState(() => _statusMessage = 'Welcome back!');
          await _ensureMinimumDuration(startTime);
          if (mounted) context.go('/');
          return;
        }
      }

      setState(() => _statusMessage = 'Ready');
      await _ensureMinimumDuration(startTime);
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _statusMessage = 'Offline mode available');
      await _ensureMinimumDuration(startTime);

      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _ensureMinimumDuration(DateTime startTime) async {
    const minimumDuration = Duration(seconds: 3);
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minimumDuration) {
      await Future.delayed(minimumDuration - elapsed);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A5F), // Primary dark navy
              Color(0xFF0F2840), // Darker navy
              Color(0xFF0D9488), // Teal accent
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            _buildBackgroundPattern(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: _buildLogo(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Animated text
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: _buildAppName(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tagline
                  FadeTransition(
                    opacity: _textOpacity,
                    child: _buildTagline(),
                  ),

                  const SizedBox(height: 60),

                  // Loading indicator
                  FadeTransition(
                    opacity: _loadingOpacity,
                    child: _buildLoadingSection(),
                  ),
                ],
              ),
            ),

            // Version and copyright
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _loadingOpacity,
                child: _buildFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Opacity(
      opacity: 0.05,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPatternPainter(),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.4),
            blurRadius: 60,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Book/ledger icon
            Icon(
              Icons.account_balance,
              size: 56,
              color: AppColors.primary,
            ),
            // Accent element
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.show_chart,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return Column(
      children: [
        Text(
          'Magic Bet',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Text(
      'Professional Accounting Software',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white.withOpacity(0.8),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      children: [
        if (_isConnecting) ...[
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 Magic Bet Ltd. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}

// Custom painter for grid pattern
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    const spacing = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
