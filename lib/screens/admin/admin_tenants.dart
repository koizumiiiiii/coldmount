import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// users list that streams accounts and shows role badges
class AdminTenants extends StatefulWidget {
  const AdminTenants({super.key});
  @override
  State<AdminTenants> createState() => _AdminTenantsState();
}

// tenants state that streams users and handles account removal
class _AdminTenantsState extends State<AdminTenants> {
  final _svc = ColdmountService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.getUsers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CmLoading();
        }
        if (snap.hasError) {
          return CmErrorCard(
            title: 'Could not load tenants', error: snap.error);
        }
        final docs = snap.data?.docs ?? [];
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${docs.length} user${docs.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateTenantScreen()));
                if (ok == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account created and synced')));
                }
              },
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add')),
          ]),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            const CmCard(child: ListTile(
              leading: Icon(Icons.people),
              title: Text('No users yet'),
              subtitle: Text('Tap Add to create the first tenant or admin account.'))),
          for (final d in docs)
            Builder(builder: (_) {
              final t = d.data() as Map<String, dynamic>;
              final photo = t['photo_url'] as String?;
              final name = (t['name'] as String?) ?? (t['email'] as String?) ?? '';
              final role = (t['role'] as String?) ?? 'tenant';
              return CmCard(child: ListTile(
                leading: photo != null && photo.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(photo))
                  : Avatar(name: name.isEmpty ? '?' : name),
                title: Text(name.isEmpty ? 'Unnamed account' : name),
                subtitle: Text(role == 'admin'
                  ? 'Admin · ${t['email'] ?? ''}'
                  : 'Unit ${t['unit'] ?? '?'} · ${t['email'] ?? ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  CmBadge(label: role, kind: role == 'admin' ? 'occupied' : 'active'),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Remove account',
                    onPressed: () => _confirmRemoveTenant(
                      context, uid: d.id,
                      name: name.isEmpty ? 'this account' : name,
                      unit: '${t['unit'] ?? ''}'),
                  ),
                ]),
              ));
            }),
        ]);
      });
  }

  // confirms removal then frees unit and keeps history records
  void _confirmRemoveTenant(BuildContext context,
      {required String uid, required String name, required String unit}) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var working = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Remove account'),
          content: Text(
            'Remove $name?\n\nTheir login stops working${unit.isNotEmpty ? ' and Unit $unit becomes vacant' : ''}. Payment and lease records are kept.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: working ? null : () async {
                setState(() => working = true);
                try {
                  await _svc.removeTenant(uid: uid, unitNo: unit);
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('$name removed${unit.isNotEmpty ? ' — Unit $unit is vacant' : ''}')));
                } catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Remove failed: $e')));
                }
              },
              child: Text(working ? 'Removing…' : 'Remove',
                style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// create account form that supports tenant and admin roles
class CreateTenantScreen extends StatefulWidget {
  const CreateTenantScreen({super.key});
  @override
  State<CreateTenantScreen> createState() => _CreateTenantScreenState();
}

// create account state that validates unit and shows password
class _CreateTenantScreenState extends State<CreateTenantScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final occCtrl = TextEditingController();
  String? selectedUnit;
  String role = 'tenant';
  late String tempPass = genTempPass();
  bool done = false, isSaving = false, sendingReset = false;
  String error = '';
  String createdEmail = '';
  String resetMsg = '';

  @override
  Widget build(BuildContext context) {
    final isTenant = role == 'tenant';
    if (done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Created')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 56),
          const Center(child: Text('Account Created',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Center(child: Text(
            isTenant
              ? 'Share the credentials below with the tenant.'
              : 'Share the credentials below with your family co-admin. They land on the admin dashboard.',
            style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 12),
          CmCard(child: Column(children: [
            ListTile(title: Text(nameCtrl.text), subtitle: const Text('Name'), dense: true),
            ListTile(title: Text(createdEmail), subtitle: const Text('Email'), dense: true),
            ListTile(title: Text(isTenant ? 'Unit $selectedUnit' : 'Admin'),
              subtitle: Text(isTenant ? 'Unit — synced' : 'Role'), dense: true),
            ListTile(title: Text(tempPass,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              subtitle: const Text('Temporary Password'), dense: true),
          ])),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'))),
        ]),
      );
    }
    final valid = nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty
      && (!isTenant || selectedUnit != null);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: FutureBuilder<QuerySnapshot>(
        future: ColdmountService().getUnits().first,
        builder: (context, snap) {
          final vacant = (snap.data?.docs ?? []).where((d) {
            final m = d.data() as Map<String, dynamic>;
            return (m['status'] as String?) != 'occupied';
          }).map((d) => (d.data() as Map<String, dynamic>)['unitNo'] as String? ?? '').where((s) => s.isNotEmpty).toList();
          // keeps selected unit valid when vacant list changes
          if (selectedUnit != null && !vacant.contains(selectedUnit)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => selectedUnit = null);
            });
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
        CmCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel(label: 'Role'),
          Row(children: [
            for (final r in ['tenant', 'admin'])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(r == 'tenant' ? 'Tenant' : 'Admin (family)'),
                  selected: role == r,
                  onSelected: (_) => setState(() => role = r)))),
          ]),
          TextField(controller: nameCtrl, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Full Name')),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: occCtrl,
            decoration: const InputDecoration(labelText: 'Occupation')),
          if (isTenant) ...[
            const SizedBox(height: 4),
            const Text('ASSIGN UNIT',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator())),
            if (snap.connectionState != ConnectionState.waiting && vacant.isEmpty)
              const Padding(padding: EdgeInsets.all(8),
                child: Text(
                  'No vacant units. Add a unit in the Units tab first — accounts cannot be made for units that do not exist.',
                  style: TextStyle(fontSize: 12, color: Colors.red))),
            Wrap(spacing: 6, children: [
              for (final u in vacant)
                ChoiceChip(
                  label: Text('Unit $u'),
                  selected: selectedUnit == u,
                  onSelected: (_) => setState(() => selectedUnit = u)),
            ]),
            const Padding(padding: EdgeInsets.only(top: 4),
              child: Text(
                'Deposits are set on the lease (standard: 2 months advance + '
                '1 month security), not here.',
                style: TextStyle(fontSize: 11, color: Colors.grey))),
          ],
        ])),
        CmCard(child: Row(children: [
          const Icon(Icons.key),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Auto-generated temporary password',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(tempPass,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900)),
          ])),
          TextButton(onPressed: () => setState(() => tempPass = genTempPass()),
            child: const Text('Regenerate')),
        ])),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CmColors.accent, foregroundColor: Colors.white),
            // saves new account with temporary password and assignment
            onPressed: (!valid || isSaving) ? null : () async {
              setState(() { isSaving = true; error = ''; resetMsg = ''; });
              try {
                // creates auth account then syncs tenant into selected unit
                await AuthService().createTenant(
                  email: emailCtrl.text, tempPassword: tempPass,
                  name: nameCtrl.text, unit: isTenant ? selectedUnit! : '',
                  phone: phoneCtrl.text, occupation: occCtrl.text,
                  role: role);
                if (isTenant) {
                  final users = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: emailCtrl.text.trim().toLowerCase())
                    .limit(1).get();
                  final newUid = users.docs.isNotEmpty ? users.docs.first.id : '';
                  await ColdmountService().assignTenantToUnit(
                    unitNo: selectedUnit!,
                    tenantName: nameCtrl.text.trim(),
                    tenantUid: newUid);
                }
                if (!mounted) return;
                createdEmail = emailCtrl.text.trim();
                setState(() { isSaving = false; done = true; });
              } on AuthError catch (e) {
                if (!mounted) return;
                setState(() { isSaving = false; error = e.message; });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  isSaving = false;
                  error = 'Could not create the account: $e';
                });
              }
            },
            child: Text(isSaving ? 'Creating…' : 'Create Account'))),
        if (error.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Column(children: [
              Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
              // shows rescue action only when the login outlives the deleted profile
              if (error.contains('login still exists'))
                TextButton(
                  onPressed: sendingReset ? null : () async {
                    setState(() { sendingReset = true; resetMsg = ''; });
                    try {
                      await AuthService()
                        .sendPasswordReset(emailCtrl.text);
                      if (!mounted) return;
                      setState(() {
                        sendingReset = false;
                        resetMsg =
                          'Reset link sent to ${emailCtrl.text.trim()}. '
                          'After reset, delete the login in Firebase Console > Authentication, then create again.';
                      });
                    } on AuthError catch (e) {
                      if (!mounted) return;
                      setState(() {
                        sendingReset = false; resetMsg = e.message;
                      });
                    }
                  },
                  child: Text(sendingReset
                    ? 'sending…' : 'send reset link')),
              if (resetMsg.isNotEmpty)
                Text(resetMsg,
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
            ])),
          ]);
        },
      ),
    );
  }
}
