import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/tenant/tenant_app.dart';
import 'screens/admin/admin_app.dart';
import 'services/auth_service.dart';

// app entry that initializes firebase before running the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// root app widget that tracks login role and uid
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? role; // holds current role which is null tenant or admin
  String? uid;  // stores firebase auth uid for the signed in user

  // signs out safely then clears role and uid state
  Future<void> _logout() async {
    try {
      await AuthService().signOut();
    } catch (_) {}
    if (mounted) setState(() { role = null; uid = null; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coldmount',
      theme: coldmountTheme(),
      // chooses home screen by user role after requiring uid
      home: role == null || uid == null
        ? LoginScreen(onLogin: (r) {
            setState(() {
              role = r;
              uid = AuthService().currentUid;
            });
          })
        : role == 'tenant' ? TenantApp(uid: uid!, onLogout: _logout)
        : AdminApp(uid: uid!, onLogout: _logout),
    );
  }
}
