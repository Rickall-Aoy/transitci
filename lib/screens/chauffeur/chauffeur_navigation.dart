import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'stats_screen.dart';
import 'gains_screen.dart';
import 'reglages_screen.dart';

class ChauffeurNavigation extends StatefulWidget {
  const ChauffeurNavigation({super.key});

  @override
  State<ChauffeurNavigation> createState() => _ChauffeurNavigationState();
}

class _ChauffeurNavigationState extends State<ChauffeurNavigation> {
  int _indexActuel = 0;

  final List<Widget> _ecrans = const [
    HomeScreen(),
    StatsScreen(),
    GainsScreen(),
    ReglagesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indexActuel,
        children: _ecrans,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _indexActuel,
          onTap: (index) => setState(() => _indexActuel = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFF6B00),
          unselectedItemColor: Colors.black38,
          backgroundColor: Colors.white,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Gains',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}