import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home.dart';
import 'services/user_account_service.dart';
import 'services/firebase_service.dart';
import 'services/realtime_database_service.dart';
import 'services/firebase_auth_service.dart';
import 'theme/liquid_theme.dart';

void main() async {
  // Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase Core
  try {
    await FirebaseService().initialize();
    debugPrint('✅ Firebase Core initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase Core initialization error: $e');
  }
  
  // Initialize Realtime Database
  try {
    await RealtimeDatabaseService().initialize();
    debugPrint('✅ Realtime Database initialized');
  } catch (e) {
    debugPrint('⚠️ Realtime Database initialization error: $e');
  }

  // Initialize Firebase Auth state listener
  try {
    await FirebaseAuthService().initializeAuthState();
    debugPrint('✅ Firebase Auth initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase Auth initialization error: $e');
  }
  
  // Initialize user service
  await UserAccountService.instance.initialize();
  
  // Optimize app startup performance - remove white screen
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  
  runApp(const MyApp());
}

/// Main application with instant onboarding/login system
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NGMY Store',
      themeMode: ThemeMode.dark,
      theme: liquidThemeData(context, isDark: true),
      home: const AppRouter(), // Smart routing
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      builder: (context, child) {
        // Prevent white flash - use dark background immediately
        return Container(
          color: const Color(0xFF1A1A2E), // Dark startup color
          child: child,
        );
      },
    );
  }
}

/// Smart router that decides which screen to show first
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
  }

  Future<void> _determineInitialScreen() async {
    try {
      final userService = UserAccountService.instance;

      Widget screenToShow;
      
      if (!userService.isLoggedIn) {
        // User not logged in - always show onboarding first (pictures)
        screenToShow = const OnboardingScreen();
      } else {
        // User is logged in - go straight to home
        screenToShow = const HomeScreen();
      }

      if (mounted) {
        setState(() => _initialScreen = screenToShow);
      }
    } catch (e) {
      // Error loading - default to onboarding
      if (mounted) {
        setState(() => _initialScreen = const OnboardingScreen());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show dark background while determining screen
    if (_initialScreen == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return _initialScreen!;
  }
}


