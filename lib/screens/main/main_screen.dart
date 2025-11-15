import 'package:car_rental_manager/models/user.dart';
import 'package:car_rental_manager/screens/main/more_screen.dart';
import 'package:car_rental_manager/screens/main/pages/bookings_screen.dart';
import 'package:car_rental_manager/screens/main/pages/car_fleet_screen.dart';
import 'package:car_rental_manager/screens/main/pages/handover_screen.dart';
import 'package:car_rental_manager/screens/main/pages/reports_screen.dart';
import 'package:car_rental_manager/screens/main/pages/search_screen.dart';
import 'package:car_rental_manager/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'pages/finances_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  GlobalRole _userRole = GlobalRole.director; // Default role set to DIRECTOR for debugging

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }
  
  String _getCurrentPageTitle() {
    final navItems = _getNavItemsForRole(_userRole);
    String roleDisplay = '';
    switch (_userRole) {
      case GlobalRole.director:
        roleDisplay = 'DIRECTOR';
        break;
      case GlobalRole.manager:
        roleDisplay = 'MANAGER';
        break;
      case GlobalRole.investor:
        roleDisplay = 'INVESTOR';
        break;
      case GlobalRole.guest:
        roleDisplay = 'GUEST';
        break;
    }
    
    if (_selectedIndex < navItems.length) {
      return '${navItems[_selectedIndex].label} [$roleDisplay]';
    }
    return 'Car Rental Manager [$roleDisplay]';
  }

  Future<void> _loadUserRole() async {
    final user = AuthService().currentFirebaseUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _userRole =
                  GlobalRole.fromString(data?['globalRole'] ?? 'MANAGER');
            });
          }
        } else {
          // If the document doesn't exist, create it with the DIRECTOR role
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? 'User',
            'globalRole': 'DIRECTOR',
            'organizations': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            setState(() {
              _userRole = GlobalRole.director;
            });
          }
        }
      } catch (e) {
        // Handle potential errors, e.g., network issues
        print("Error loading user role: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки роли пользователя: $e')),
          );
        }
      }
    }
  }

  List<Widget> _getPagesForRole(GlobalRole role) {
    final List<Widget> pages = [];
    
    // Отчеты - DIRECTOR, MANAGER, OWNER
    if (role == GlobalRole.director || role == GlobalRole.manager || role == GlobalRole.investor) {
      pages.add(const ReportsScreen());
    }
    
    // Финансы - OWNER
    if (role == GlobalRole.investor) {
      pages.add(const FinancesScreen());
    }
    
    // Автопарк - OWNER
    if (role == GlobalRole.investor) {
      pages.add(const CarFleetScreen());
    }
    
    // Брони - DIRECTOR, MANAGER (и OWNER для контроля загрузки)
    if (role == GlobalRole.director || role == GlobalRole.manager || role == GlobalRole.investor) {
      pages.add(const BookingsScreen());
    }
    
    // Поиск - DIRECTOR, MANAGER
    if (role == GlobalRole.director || role == GlobalRole.manager) {
      pages.add(const SearchScreen());
    }
    
    // Выдача - DIRECTOR, MANAGER
    if (role == GlobalRole.director || role == GlobalRole.manager) {
      pages.add(const HandoverScreen());
    }
    
    // Еще - всегда добавляем для всех ролей
    pages.add(MoreScreen(userRole: role));
    
    return pages;
  }

  List<BottomNavigationBarItem> _getNavItemsForRole(GlobalRole role) {
    final List<BottomNavigationBarItem> items = [];
    
    // Отчеты - DIRECTOR, MANAGER, OWNER
    if (role == GlobalRole.director || role == GlobalRole.manager || role == GlobalRole.investor) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'Отчеты',
      ));
    }
    
    // Финансы - OWNER
    if (role == GlobalRole.investor) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.attach_money),
        label: 'Финансы',
      ));
    }
    
    // Автопарк - OWNER
    if (role == GlobalRole.investor) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.directions_car),
        label: 'Автопарк',
      ));
    }
    
    // Брони - DIRECTOR, MANAGER, OWNER
    if (role == GlobalRole.director || role == GlobalRole.manager || role == GlobalRole.investor) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Брони',
      ));
    }
    
    // Поиск - DIRECTOR, MANAGER
    if (role == GlobalRole.director || role == GlobalRole.manager) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Поиск',
      ));
    }
    
    // Выдача - DIRECTOR, MANAGER
    if (role == GlobalRole.director || role == GlobalRole.manager) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.outbox),
        label: 'Выдача',
      ));
    }
    
    // Еще - DIRECTOR, MANAGER, OWNER
    if (role == GlobalRole.director || role == GlobalRole.manager || role == GlobalRole.investor) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz),
        label: 'Еще',
      ));
    }
    
    return items;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPagesForRole(_userRole);
    final navItems = _getNavItemsForRole(_userRole);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getCurrentPageTitle()),
        actions: [
          // Inbox - available for DIRECTOR, MANAGER, OWNER
          if (_userRole == GlobalRole.director ||
              _userRole == GlobalRole.manager ||
              _userRole == GlobalRole.investor)
            IconButton(
              icon: const Icon(Icons.inbox),
              tooltip: 'Входящие',
              onPressed: () {
                // TODO: Navigate to Inbox screen
              },
            ),
          // Support - available for DIRECTOR, MANAGER, OWNER
          if (_userRole == GlobalRole.director ||
              _userRole == GlobalRole.manager ||
              _userRole == GlobalRole.investor)
            IconButton(
              icon: const Icon(Icons.support_agent),
              tooltip: 'Поддержка',
              onPressed: () {
                // TODO: Navigate to Support screen
              },
            ),
          // Role switcher for debugging - always visible in dev mode
          PopupMenuButton<GlobalRole>(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Смена роли (отладка)',
            onSelected: (GlobalRole role) async {
              // Сохраняем роль в Firestore и обновляем локально
              final user = AuthService().currentFirebaseUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'globalRole': role.value});
              }
              setState(() {
                _userRole = role;
                _selectedIndex = 0; // Сброс на первую страницу при смене роли
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Интерфейс обновлен для роли: ${role.value}')),
                );
              }
            },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<GlobalRole>>[
                _buildRoleMenuItem(
                    GlobalRole.director, 'DIRECTOR', Icons.business_center),
                _buildRoleMenuItem(
                    GlobalRole.manager, 'MANAGER', Icons.person_outline),
                _buildRoleMenuItem(
                    GlobalRole.investor, 'INVESTOR', Icons.account_balance_wallet),
              ],
            ),
          // My Account - available for all
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Мой аккаунт',
            onPressed: () {
              // TODO: Navigate to My Account screen
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex >= pages.length ? 0 : _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: navItems.isNotEmpty ? BottomNavigationBar(
        currentIndex: _selectedIndex >= navItems.length ? 0 : _selectedIndex,
        onTap: _onItemTapped,
        items: navItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ) : null,
    );
  }

  PopupMenuItem<GlobalRole> _buildRoleMenuItem(
      GlobalRole role, String title, IconData icon) {
    final isSelected = _userRole == role;
    return PopupMenuItem<GlobalRole>(
      value: role,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

