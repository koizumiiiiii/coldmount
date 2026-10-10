// password change card letting tenants update their own password
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'common.dart';

// expandable card handling secure tenant password change flow
class ChangePasswordCard extends StatefulWidget {
  const ChangePasswordCard({super.key});
  @override
  State<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<ChangePasswordCard> {
  bool showForm = false, saving = false, obscure = true;
  String msg = ''; bool ok = false;
  final curCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CmCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        leading: const Icon(Icons.lock),
        title: const Text('Change Password',
          style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Swap your temp password for your own',
          style: TextStyle(fontSize: 12)),
        trailing: Icon(showForm
          ? Icons.expand_less : Icons.expand_more),
        onTap: () => setState(() {
          showForm = !showForm; msg = ''; ok = false;
        }),
      ),
      if (showForm) ...[
        TextField(controller: curCtrl, obscureText: obscure,
          decoration: const InputDecoration(
            labelText: 'Current (temp) password')),
        TextField(controller: newCtrl, obscureText: obscure,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'New password (min. 6 characters)')),
        TextField(controller: confirmCtrl, obscureText: obscure,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Confirm new password')),
        Row(children: [
          TextButton(
            onPressed: () => setState(() => obscure = !obscure),
            child: Text(obscure ? 'Show' : 'Hide')),
          const Spacer(),
          ElevatedButton(
            onPressed: saving ? null : () async {
              setState(() { saving = true; msg = ''; ok = false; });
              if (newCtrl.text != confirmCtrl.text) {
                setState(() {
                  saving = false; ok = false;
                  msg = 'New passwords do not match.';
                });
                return;
              }
              try {
                await AuthService().changePassword(
                  currentPassword: curCtrl.text,
                  newPassword: newCtrl.text);
                if (!mounted) return;
                setState(() {
                  saving = false; ok = true;
                  msg = 'Password changed. Use it next sign-in.';
                });
                curCtrl.clear(); newCtrl.clear(); confirmCtrl.clear();
              } on AuthError catch (e) {
                if (!mounted) return;
                setState(() {
                  saving = false; ok = false; msg = e.message;
                });
              } catch (_) {
                if (!mounted) return;
                setState(() {
                  saving = false; ok = false;
                  msg = 'Could not change password. Try again.';
                });
              }
            },
            child: Text(saving ? 'Saving…' : 'Update Password')),
        ]),
        if (msg.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(msg,
              style: TextStyle(
                fontSize: 12,
                color: ok ? Colors.green : Colors.red))),
      ],
    ]));
  }
}
