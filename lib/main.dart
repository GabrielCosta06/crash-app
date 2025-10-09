import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'models/crashpad.dart';
import 'screens/account_screen.dart';
import 'screens/create_listing.dart';
import 'screens/delete_listings.dart';
import 'screens/find_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/owner_dashboard.dart';
import 'screens/owner_details_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/subscription_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRepository _repository;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _repository = AppRepository()
      ..addListener(_handleRepositoryChanged);
    _isAuthenticated = _repository.isAuthenticated;
  }

  @override
  void dispose() {
    _repository.removeListener(_handleRepositoryChanged);
    super.dispose();
  }

  void _handleRepositoryChanged() {
    final isLoggedIn = _repository.isAuthenticated;
    if (mounted && isLoggedIn != _isAuthenticated) {
      setState(() {
        _isAuthenticated = isLoggedIn;
      });
    }
  }

  bool _isPublicRoute(String? name) =>
      name == '/login' || name == '/signup' || name == '/forgot-password';

  Route<dynamic> _generateRoute(RouteSettings settings) {
    final destination = settings.name ?? '/login';
    final bool allowWithoutAuth = _isPublicRoute(destination);

    // Use the repository's authentication state directly for more reliability
    final isCurrentlyAuthenticated = _repository.isAuthenticated;
    
    // Only redirect to login for explicit route navigation, not for back navigation
    if (!isCurrentlyAuthenticated && !allowWithoutAuth) {
      return MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onAuthenticated: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
      );
    }

    switch (destination) {
      case '/login':
        return MaterialPageRoute<void>(
          builder: (context) => LoginScreen(
            onAuthenticated: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        );
      case '/signup':
        return MaterialPageRoute<void>(
          builder: (context) => const SignupScreen(),
        );
      case '/home':
        return MaterialPageRoute<void>(
          builder: (context) => const MainScreen(),
        );
      case '/owner':
        return MaterialPageRoute<void>(
          builder: (context) => const OwnerDashboardScreen(),
        );
      case '/create_listing':
        return MaterialPageRoute<void>(
          builder: (context) => const CreateListingScreen(),
        );
      case '/delete_listings':
        return MaterialPageRoute<void>(
          builder: (context) => const DeleteListingsScreen(),
        );
      case '/forgot-password':
        return MaterialPageRoute<void>(
          builder: (context) => const ForgotPasswordScreen(),
        );
      case '/owner-details':
        final crashpad = settings.arguments as Crashpad;
        return MaterialPageRoute<void>(
          builder: (context) => OwnerDetailsScreen(crashpad: crashpad),
        );
      case '/subscribe':
        return MaterialPageRoute<void>(
          builder: (context) => const SubscriptionScreen(),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (context) => LoginScreen(
            onAuthenticated: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppRepository>.value(
      value: _repository,
      child: Consumer<AppRepository>(
        builder: (context, repository, child) {
          return MaterialApp(
            title: 'Crashpad',
            debugShowCheckedModeBanner: false,
            theme: repository.isDarkTheme ? AppTheme.dark : AppTheme.light,
            initialRoute: _isAuthenticated ? '/home' : '/login',
            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      HomeScreen(onUpdateIndex: _updateIndex),
      const FindScreen(),
      const OwnerDashboardScreen(),
      const AccountScreen(),
    ];
  }

  void _updateIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavigationTapped(int index) => _updateIndex(index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onNavigationTapped,
            type: BottomNavigationBarType.fixed,
            items: [
              _animatedItem(Icons.dashboard_customize_outlined, 'Home', 0),
              _animatedItem(Icons.search_rounded, 'Find', 1),
              _animatedItem(Icons.analytics_outlined, 'Owner', 2),
              _animatedItem(Icons.person_outline, 'Account', 3),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _animatedItem(IconData icon, String label, int index) {
    final selected = index == _currentIndex;
    return BottomNavigationBarItem(
      icon: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 1.1 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selected ? 1.0 : 0.7,
          child: Icon(icon),
        ),
      ),
      label: label,
    );
  }
}
