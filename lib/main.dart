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

/// Shared duration for page swaps within the main navigation shell.
const Duration _navAnimationDuration = Duration(milliseconds: 260);

/// Entry point for the Crashpad experience.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Root widget responsible for wiring providers, routing and theming.
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
    _repository = AppRepository()..addListener(_handleRepositoryChanged);
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
      setState(() => _isAuthenticated = isLoggedIn);
    }
  }

  /// Returns whether unauthenticated users can access the given route.
  bool _isPublicRoute(String? name) =>
      name == '/login' || name == '/signup' || name == '/forgot-password';

  /// Handles route creation while respecting the current auth state.
  Route<dynamic> _generateRoute(RouteSettings settings) {
    final destination = settings.name ?? '/login';
    final allowWithoutAuth = _isPublicRoute(destination);
    final isAuthenticated = _repository.isAuthenticated;

    if (!isAuthenticated && !allowWithoutAuth) {
      return MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onAuthenticated: () =>
              Navigator.of(context).pushReplacementNamed('/home'),
        ),
        settings: settings,
      );
    }

    WidgetBuilder builder;
    switch (destination) {
      case '/login':
        builder = (context) => LoginScreen(
              onAuthenticated: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
            );
        break;
      case '/signup':
        builder = (context) => const SignupScreen();
        break;
      case '/home':
        builder = (context) => const MainScreen();
        break;
      case '/owner':
        builder = (context) => const OwnerDashboardScreen();
        break;
      case '/create_listing':
        builder = (context) => const CreateListingScreen();
        break;
      case '/delete_listings':
        builder = (context) => const DeleteListingsScreen();
        break;
      case '/forgot-password':
        builder = (context) => const ForgotPasswordScreen();
        break;
      case '/owner-details':
        final crashpad = settings.arguments as Crashpad;
        builder = (context) => OwnerDetailsScreen(crashpad: crashpad);
        break;
      case '/subscribe':
        builder = (context) => const SubscriptionScreen();
        break;
      default:
        builder = (context) => LoginScreen(
              onAuthenticated: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
            );
    }

    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppRepository>.value(
      value: _repository,
      child: Consumer<AppRepository>(
        builder: (_, repository, __) => MaterialApp(
          title: 'Crashpad',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          initialRoute: _isAuthenticated ? '/home' : '/login',
          onGenerateRoute: _generateRoute,
        ),
      ),
    );
  }
}

/// Hosts the main app destinations behind adaptive mobile/web navigation.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const List<_Destination> _destinations = <_Destination>[
    _Destination(icon: Icons.dashboard_customize_outlined, label: 'Home'),
    _Destination(icon: Icons.search_rounded, label: 'Find'),
    _Destination(icon: Icons.analytics_outlined, label: 'Owner'),
    _Destination(icon: Icons.person_outline, label: 'Account'),
  ];

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

  /// Updates the selected destination and triggers the animated swap.
  void _updateIndex(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  void _onNavigationTapped(int index) => _updateIndex(index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 900;
        final page = AnimatedSwitcher(
          duration: _navAnimationDuration,
          transitionBuilder: (child, animation) {
            final offsetTween =
                Tween<Offset>(begin: const Offset(0.025, 0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(offsetTween),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screens[_currentIndex],
          ),
        );

        if (useSidebar) {
          return Scaffold(
            body: Row(
              children: [
                _SidebarNavigation(
                  currentIndex: _currentIndex,
                  destinations: _destinations,
                  onDestinationSelected: _onNavigationTapped,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          body: page,
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _destinations.length;
                  const horizontalInset = 8.0;
                  const verticalInset = 4.0;
                  final highlightLeft =
                      itemWidth * _currentIndex + horizontalInset / 2;
                  final highlightWidth = itemWidth - horizontalInset;
                  final theme = Theme.of(context);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                theme.bottomNavigationBarTheme.backgroundColor,
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: _navAnimationDuration,
                        curve: Curves.easeOutCubic,
                        left: highlightLeft,
                        width: highlightWidth,
                        top: verticalInset,
                        bottom: verticalInset,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      BottomNavigationBar(
                        currentIndex: _currentIndex,
                        onTap: _onNavigationTapped,
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        items: List.generate(
                          _destinations.length,
                          (index) => _navItem(_destinations[index], index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds an animated navigation item that subtly scales when selected.
  BottomNavigationBarItem _navItem(_Destination destination, int index) {
    final isSelected = index == _currentIndex;
    return BottomNavigationBarItem(
      icon: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isSelected ? 1.08 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSelected ? 1.0 : 0.7,
          child: Icon(destination.icon),
        ),
      ),
      label: destination.label,
    );
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: SizedBox(
        width: 248,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      gradient: AppGradients.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apartment_rounded),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Crash App',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: NavigationRail(
                extended: true,
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.none,
                destinations: destinations
                    .map(
                      (destination) => NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact representation of a bottom navigation destination.
class _Destination {
  const _Destination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
