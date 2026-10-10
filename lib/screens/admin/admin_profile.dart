import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/change_password.dart';
import '../../widgets/common.dart';

// admin profile sheet that shows account and changes photo
class AdminProfileSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String uid;
  final Future<void> Function() onPhotoChanged;
  final VoidCallback onLogout;
  const AdminProfileSheet({super.key, required this.profile,
    required this.uid, required this.onPhotoChanged, required this.onLogout});
  @override
  State<AdminProfileSheet> createState() => _AdminProfileSheetState();
}

// profile sheet state that handles photo upload and errors
class _AdminProfileSheetState extends State<AdminProfileSheet> {
  bool uploading = false;
  String? error;

  // uploads new admin photo and refreshes profile after success
  Future<void> changePhoto() async {
    setState(() { uploading = true; error = null; });
    try {
      final picked = await CloudinaryService().pickUnitImage();
      if (picked == null) {
        if (mounted) setState(() => uploading = false);
        return;
      }
      await AuthService().updatePhotoUrl(widget.uid, picked.url);
      await widget.onPhotoChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { uploading = false; error = 'Upload failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final photo = p['photo_url'] as String?;
    final name = (p['name'] as String?) ?? '';
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.85,
      builder: (_, c) => ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Stack(children: [
          photo != null && photo.isNotEmpty
            ? CircleAvatar(radius: 36, backgroundImage: NetworkImage(photo))
            : Avatar(name: name.isEmpty ? '?' : name, size: 72),
          Positioned(bottom: 0, right: 0,
            child: GestureDetector(
              onTap: uploading ? null : changePhoto,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: CmColors.primary, shape: BoxShape.circle),
                child: uploading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt, size: 14, color: Colors.white)))),
        ])),
        const SizedBox(height: 8),
        Center(child: Text(name.isEmpty ? 'Admin' : name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const Center(child: CmBadge(label: 'Admin', kind: 'occupied')),
        Center(child: TextButton(
          onPressed: uploading ? null : changePhoto,
          child: Text(uploading ? 'Uploading…' : 'Change Photo'))),
        if (error != null)
          Center(child: Text(error!,
            style: const TextStyle(color: Colors.red, fontSize: 12))),
        const SizedBox(height: 8),
        const SectionLabel(label: 'Account Information'),
        CmCard(child: Column(children: [
          ListTile(leading: const Icon(Icons.mail),
            title: Text('${p['email'] ?? ''}'), dense: true),
          ListTile(leading: const Icon(Icons.phone),
            title: Text('${(p['phone'] as String?)?.isNotEmpty == true ? p['phone'] : '—'}'),
            dense: true),
          ListTile(leading: const Icon(Icons.work),
            title: Text('${(p['occupation'] as String?)?.isNotEmpty == true ? p['occupation'] : 'Property admin'}'),
            dense: true),
        ])),
        const SizedBox(height: 8),
        const ChangePasswordCard(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onLogout();
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Sign Out', style: TextStyle(color: Colors.red))),
      ]));
  }
}
