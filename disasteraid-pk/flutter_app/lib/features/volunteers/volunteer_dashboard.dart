import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:disasteraid_pk/features/volunteers/complete_profile_screen.dart';
import 'package:disasteraid_pk/features/volunteers/volunteer_tasks_screen.dart';
import 'package:disasteraid_pk/features/volunteers/volunteer_map_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_list_screen.dart'; // ADD THIS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});
  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VolunteerTasksTab(),
    const VolunteerMapScreen(),
    const ChatListScreen(), // ADD THIS
    const VolunteerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<ChatBadgeProvider>().unreadCount; // ADD THIS

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem( // UPDATE THIS
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Move your old VolunteerTasksScreen body into this tab
class VolunteerTasksTab extends StatelessWidget {
  const VolunteerTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const VolunteerTasksScreen(); // Your existing screen
  }
}

// Volunteer Profile Tab
class VolunteerProfileTab extends StatelessWidget {
  const VolunteerProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.volunteer_activism, size: 50)),
          const SizedBox(height: 16),
          Center(child: Text(user?['name']?? 'Volunteer', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text(user?['email']?? '', style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CompleteProfileScreen()));
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Delivery History'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Navigate to history screen
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => context.read<AuthProvider>().logout(),
            ),
          ),
        ],
      ),
    );
  }
}