import 'package:flutter/material.dart';
import 'package:beangle_app/auth/auth_find_info.dart';
import 'package:beangle_app/auth/auth_page.dart';
import 'package:beangle_app/auth/auth_sign_page.dart';
import 'package:beangle_app/dashboard/dashboard.dart';
import 'package:beangle_app/reservation/reservation.dart';
import 'package:beangle_app/user/map_for_user.dart';
import 'package:beangle_app/worker/worker_home.dart';

class AppRouteItem {
  const AppRouteItem({
    required this.routeName,
    required this.label,
    required this.builder,
  });

  final String routeName;
  final String label;
  final WidgetBuilder builder;
}

class AppRoutes {
  static const auth = '/';
  static const authFindInfo = '/auth-find-info';
  static const authSign = '/auth-sign';
  static const dashboard = '/dashboard';
  static const reservation = '/reservation';
  static const userMap = '/user-map';
  static const workerMap = '/worker-map';

  static final List<AppRouteItem> items = [
    AppRouteItem(
      routeName: auth,
      label: 'Auth',
      builder: (_) => const AuthPage(),
    ),
    AppRouteItem(
      routeName: authFindInfo,
      label: 'Find Info',
      builder: (_) => const AuthFindInfoPage(),
    ),
    AppRouteItem(
      routeName: authSign,
      label: 'Sign Up',
      builder: (_) => const AuthSignPage(),
    ),
    AppRouteItem(
      routeName: dashboard,
      label: 'Dashboard',
      builder: (_) => const DashboardPage(),
    ),
    AppRouteItem(
      routeName: reservation,
      label: 'Reservation',
      builder: (_) => const ReservationPage(),
    ),
    AppRouteItem(
      routeName: userMap,
      label: 'User Map',
      builder: (_) => const MapForUserPage(),
    ),
    AppRouteItem(
      routeName: workerMap,
      label: 'Worker Map',
      builder: (_) => const WorkerHomePage(),
    ),
  ];

  static Map<String, WidgetBuilder> get routeMap => {
    for (final item in items) item.routeName: item.builder,
  };
}

class GlobalRouteMenu extends StatelessWidget {
  const GlobalRouteMenu({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Open routes',
      icon: const Icon(Icons.route),
      onSelected: (routeName) {
        if (routeName == currentRoute) {
          return;
        }

        Navigator.of(context).pushNamed(routeName);
      },
      itemBuilder: (context) {
        return AppRoutes.items.map((item) {
          final isCurrentPage = item.routeName == currentRoute;
          return PopupMenuItem<String>(
            value: item.routeName,
            enabled: !isCurrentPage,
            child: Row(
              children: [
                Expanded(child: Text(item.label)),
                if (isCurrentPage)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.check, size: 18),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.body,
  });

  final String title;
  final String currentRoute;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFeeeeee),
      appBar: AppBar(
        title: Text(title),
        actions: [GlobalRouteMenu(currentRoute: currentRoute)],
      ),
      body: body,
    );
  }
}
