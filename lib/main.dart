import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'models/app_user.dart';
import 'screens/checkout_screen.dart';
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
import 'widgets/app_components.dart';

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

  bool _isManagementRoute(String destination) =>
      destination == '/management' || destination == '/owner';

  bool _isOwnerOnlyRoute(String destination) =>
      _isManagementRoute(destination) ||
      destination == '/create_listing' ||
      destination == '/delete_listings' ||
      destination == '/edit_listing';

  String _landingRoute() {
    return _repository.currentUser?.userType == AppUserType.owner
        ? '/management'
        : '/home';
  }

  /// Handles route creation while respecting the current auth state.
  Route<dynamic> _generateRoute(RouteSettings settings) {
    final destination = settings.name ?? '/login';
    final allowWithoutAuth = _isPublicRoute(destination);
    final isAuthenticated = _repository.isAuthenticated;

    if (!isAuthenticated && !allowWithoutAuth) {
      return MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onAuthenticated: () =>
              Navigator.of(context).pushReplacementNamed(_landingRoute()),
        ),
        settings: settings,
      );
    }

    if (isAuthenticated &&
        _isOwnerOnlyRoute(destination) &&
        _repository.currentUser?.userType != AppUserType.owner) {
      return MaterialPageRoute<void>(
        builder: (context) => const MainScreen(),
        settings: const RouteSettings(name: '/home'),
      );
    }

    WidgetBuilder builder;
    switch (destination) {
      case '/login':
        builder = (context) => LoginScreen(
              onAuthenticated: () =>
                  Navigator.of(context).pushReplacementNamed(_landingRoute()),
            );
        break;
      case '/signup':
        builder = (context) => const SignupScreen();
        break;
      case '/home':
        final args = settings.arguments;
        builder = (context) => MainScreen(
              initialFindQuery: args is String ? args : null,
              initialIndex: args is String ? 1 : 0,
            );
        break;
      case '/management':
      case '/owner':
        builder = (context) => const MainScreen(initialIndex: 2);
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
      case '/edit_listing':
        final crashpad = settings.arguments as Crashpad;
        builder = (context) => CreateListingScreen(crashpad: crashpad);
        break;
      case '/checkout':
        final arguments = settings.arguments as CheckoutArguments;
        builder = (context) => CheckoutScreen(arguments: arguments);
        break;
      case '/subscribe':
        builder = (context) => const SubscriptionScreen();
        break;
      default:
        builder = (context) => LoginScreen(
              onAuthenticated: () =>
                  Navigator.of(context).pushReplacementNamed(_landingRoute()),
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
          title: 'Crash App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          initialRoute: _isAuthenticated ? _landingRoute() : '/login',
          onGenerateRoute: _generateRoute,
        ),
      ),
    );
  }
}

/// Hosts the main app destinations behind adaptive mobile/web navigation.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialFindQuery,
  });

  final int initialIndex;
  final String? initialFindQuery;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  String? _findSearchQuery;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _findSearchQuery = widget.initialFindQuery;
  }

  /// Updates the selected destination and triggers the animated swap.
  void _updateIndex(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  void _onNavigationTapped(int index) => _updateIndex(index);

  void _openFindWithQuery(String query) {
    setState(() {
      _findSearchQuery = query.trim();
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final canManage = repository.currentUser?.userType == AppUserType.owner;
    final destinations = <_Destination>[
      const _Destination(
          icon: Icons.dashboard_customize_outlined, label: 'Home'),
      const _Destination(icon: Icons.search_rounded, label: 'Find'),
      if (canManage)
        const _Destination(
          icon: Icons.analytics_outlined,
          label: 'Management',
        ),
      const _Destination(icon: Icons.person_outline, label: 'Account'),
    ];
    final managementIndex = canManage ? 2 : null;
    final screens = <Widget>[
      HomeScreen(
        onUpdateIndex: _updateIndex,
        managementIndex: managementIndex,
        onFindSearch: _openFindWithQuery,
      ),
      FindScreen(
        key: ValueKey<String>(_findSearchQuery ?? ''),
        initialSearchQuery: _findSearchQuery,
      ),
      if (canManage) const OwnerDashboardScreen(),
      const AccountScreen(),
    ];
    final safeIndex = _currentIndex.clamp(0, screens.length - 1).toInt();
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }

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
            key: ValueKey<int>(safeIndex),
            child: screens[safeIndex],
          ),
        );

        if (useSidebar) {
          return Scaffold(
            body: Row(
              children: [
                _SidebarNavigation(
                  currentIndex: safeIndex,
                  destinations: destinations,
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
                  final itemWidth = constraints.maxWidth / destinations.length;
                  const horizontalInset = 8.0;
                  const verticalInset = 4.0;
                  final highlightLeft =
                      itemWidth * safeIndex + horizontalInset / 2;
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
                        currentIndex: safeIndex,
                        onTap: _onNavigationTapped,
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        items: List.generate(
                          destinations.length,
                          (index) =>
                              _navItem(destinations[index], index, safeIndex),
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
  BottomNavigationBarItem _navItem(
    _Destination destination,
    int index,
    int selectedIndex,
  ) {
    final isSelected = index == selectedIndex;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: 16),
                  Consumer<AppRepository>(
                    builder: (context, repo, _) {
                      final user = repo.currentUser;
                      if (user == null) return const SizedBox.shrink();
                      return StatusBadge(
                        label: user.isOwner ? 'OWNER' : 'CREW',
                        icon: user.isOwner
                            ? Icons.business_center_outlined
                            : Icons.flight_outlined,
                        color:
                            user.isOwner ? AppPalette.warning : AppPalette.cyan,
                      );
                    },
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
