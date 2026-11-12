import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../medicine/add_medicine_screen.dart';
import '../profile/profile_screen.dart';
import 'available_tab.dart';
import 'my_donations_tab.dart';
import 'my_requests_tab.dart';

/// الواجهة الرئيسية للمتبرع / المحتاج.
class UserHome extends StatefulWidget {
  const UserHome({super.key, required this.user});
  final AppUser user;

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _index = 0;

  static const _titles = [AppConstants.appName, 'طلباتي', 'تبرعاتي', 'حسابي'];

  void _openAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMedicineScreen(user: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final showFab = _index == 0 || _index == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index != 3)
            IconButton(
              tooltip: 'حسابي',
              onPressed: () => setState(() => _index = 3),
              icon: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white,
                child: Text(
                  user.initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00695C),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          AvailableTab(user: user),
          MyRequestsTab(user: user),
          MyDonationsTab(user: user),
          ProfileView(user: user),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _openAddMedicine,
              icon: const Icon(Icons.add_rounded),
              label: const Text('تبرع الآن'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded),
            label: 'الأدوية المتاحة',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism_rounded),
            label: 'تبرعاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
