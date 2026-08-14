import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation shell. Five destinations, no more -- the brief asks for a
/// calm consumer app, not a tool with a dense navigation tree.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
    ('/goals', Icons.flag_outlined, Icons.flag_rounded, 'Goals'),
    ('/calendar', Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Schedule'),
    ('/progress', Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
    ('/profile', Icons.person_outline_rounded, Icons.person_rounded, 'You'),
  ];

  int _indexFor(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => context.go(_tabs[i].$1),
          items: [
            for (var i = 0; i < _tabs.length; i++)
              BottomNavigationBarItem(
                icon: Icon(i == index ? _tabs[i].$3 : _tabs[i].$2),
                label: _tabs[i].$4,
              ),
          ],
        ),
      ),
    );
  }
}
