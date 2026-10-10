import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'admin_dashboard.dart';
import 'admin_leases.dart';
import 'admin_more.dart';
import 'admin_payments.dart';
import 'admin_profile.dart';
import 'admin_tenants.dart';
import 'admin_units.dart';

// admin shell that hosts tabs and switches more screens
class AdminApp extends StatefulWidget {
  final String uid;
  final VoidCallback onLogout;
  const AdminApp({super.key, required this.uid, required this.onLogout});
  @override
  State<AdminApp> createState() => _AdminAppState();
}

// admin app state that manages tab index and profile data
class _AdminAppState extends State<AdminApp> {
  int tab = 0;
  String? more; // holds active more screen name for deposits violations and others
  Map<String, dynamic>? profile;

  // opens more screen by updating selected more name
  void openMore(String s) => setState(() => more = s);

  // loads admin profile from auth service for avatar display
  Future<void> _loadProfile() async {
    try {
      final p = await AuthService().fetchProfile(widget.uid);
      if (mounted) setState(() => profile = p);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // opens admin profile sheet and reloads photo after close
  void openProfile() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => AdminProfileSheet(
        profile: profile ?? {},
        uid: widget.uid,
        onPhotoChanged: _loadProfile,
        onLogout: widget.onLogout,
      )).then((_) {
        if (mounted) _loadProfile();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (more == 'deposits') {
      return DepositsScreen(onBack: () => setState(() => more = null));
    }
    if (more == 'violations') {
      return ViolationsScreen(onBack: () => setState(() => more = null));
    }
    if (more == 'maintenance') {
      return MaintenanceScreen(onBack: () => setState(() => more = null));
    }
    if (more == 'announcements') {
      return AnnouncementsScreen(onBack: () => setState(() => more = null));
    }

    final pages = [
      AdminDashboard(
        onNavigateTab: (t) => setState(() => tab = t),
        onOpenMore: openMore),
      const AdminUnits(),
      const AdminTenants(),
      const AdminLeases(),
      const AdminPayments(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Coldmount Admin'), actions: [
        Builder(builder: (context) {
          final photo = profile?['photo_url'] as String?;
          final name = (profile?['name'] as String?) ?? '';
          return GestureDetector(
            onTap: openProfile,
            child: Padding(padding: const EdgeInsets.only(right: 4),
              child: photo != null && photo.isNotEmpty
                ? CircleAvatar(radius: 16,
                    backgroundImage: NetworkImage(photo))
                : Avatar(name: name.isEmpty ? '?' : name, size: 32)),
          );
        }),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            openMore(v);
          },
          itemBuilder: (_) => const [
          PopupMenuItem(value: 'deposits', child: Text('Deposits')),
          PopupMenuItem(value: 'violations', child: Text('Violations')),
          PopupMenuItem(value: 'announcements', child: Text('Announcements')),
          PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
        ]),
        IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign Out',
          onPressed: widget.onLogout),
      ]),
      body: pages[tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab, type: BottomNavigationBarType.fixed,
        selectedItemColor: CmColors.primary,
        onTap: (i) => setState(() => tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Units'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Leases'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Payments'),
        ],
      ),
    );
  }
}
