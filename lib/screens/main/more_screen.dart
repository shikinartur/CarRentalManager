import 'package:flutter/material.dart';
import 'package:car_rental_manager/models/user.dart';

class MoreScreen extends StatelessWidget {
  final GlobalRole userRole;

  const MoreScreen({super.key, required this.userRole});

  bool _canAccessFinances() => userRole == GlobalRole.director || userRole == GlobalRole.manager;
  bool _canAccessCarFleet() => userRole == GlobalRole.director || userRole == GlobalRole.manager;
  bool _canAccessManagers() => userRole == GlobalRole.director;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            if (_canAccessFinances())
              _buildMenuCard(
                context,
                title: 'Финансы',
                icon: Icons.attach_money,
                color: Colors.green,
                onTap: () {
                  // TODO: Implement navigation to Finances
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Финансы - в разработке')),
                  );
                },
              ),
            if (_canAccessCarFleet())
              _buildMenuCard(
                context,
                title: 'Автопарк',
                icon: Icons.directions_car,
                color: Colors.blue,
                onTap: () {
                  // TODO: Implement navigation to Car Fleet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Автопарк - в разработке')),
                  );
                },
              ),
            if (_canAccessManagers())
              _buildMenuCard(
                context,
                title: 'Менеджеры',
                icon: Icons.people,
                color: Colors.purple,
                onTap: () {
                  // TODO: Implement navigation to Managers
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Менеджеры - в разработке')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
