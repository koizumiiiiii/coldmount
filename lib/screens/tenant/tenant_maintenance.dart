import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/cloudinary_service.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// maintenance tab that lists tickets with progress and status
class TenantMaintenance extends StatelessWidget {
  final String uid;
  final VoidCallback onNewRequest;
  const TenantMaintenance({super.key, required this.uid,
    required this.onNewRequest});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: ColdmountService().getTenantTickets(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CmLoading();
        }
        if (snap.hasError) {
          return CmErrorCard(
            title: 'Could not load requests', error: snap.error);
        }
        final docs =
          ColdmountService.sortByCreatedDesc(snap.data?.docs ?? []);
        return ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(onPressed: onNewRequest,
              icon: const Icon(Icons.add), label: const Text('New Request'))),
          if (docs.isEmpty)
            const CmCard(child: ListTile(
              leading: Icon(Icons.build),
              title: Text('No requests yet'),
              subtitle: Text('Tap New Request to report a problem in your unit.'))),
          for (final d in docs)
            Builder(builder: (_) {
              final m = d.data() as Map<String, dynamic>;
              final status = (m['status'] as String?) ?? 'submitted';
              final category = (m['category'] as String?) ?? 'minor';
              final photo = (m['photo_url'] as String?) ?? '';
              final assignee = (m['assignee'] as String?) ?? '';
              final step = status == 'in-progress' ? 1
                : status == 'resolved' ? 2 : 0;
              return CmCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (photo.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(photo, height: 140,
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const SizedBox()))),
                Text('${m['title'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Wrap(spacing: 6, children: [
                  CmBadge(label: category, kind: category),
                  CmBadge(label: status.replaceAll('-', ' '), kind: status),
                ]),
                const SizedBox(height: 4),
                Text('${m['description'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Row(children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(child: Column(children: [
                      Container(height: 6,
                        decoration: BoxDecoration(
                          color: i <= step ? CmColors.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 2),
                      Text(['Submitted', 'In Progress', 'Resolved'][i],
                        style: const TextStyle(fontSize: 10)),
                    ])),
                ]),
                if (assignee.isNotEmpty && status == 'in-progress')
                  Text('Assigned to $assignee',
                    style: const TextStyle(fontSize: 12, color: Colors.blue)),
                if (status == 'resolved')
                  const Text('Resolved ✓',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
              ]));
            }),
        ]);
      });
  }
}

// sheet that submits new maintenance ticket with optional photo
class RequestSheet extends StatefulWidget {
  final String uid, tenantName, unit;
  const RequestSheet({super.key, required this.uid,
    required this.tenantName, required this.unit});
  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String category = 'minor';
  bool isSubmitting = false;
  bool uploadingPhoto = false;
  String? photoUrl;
  String error = '';
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Submit Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Issue Title')),
          Row(children: [
            for (final c in ['minor', 'major'])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(c), selected: category == c,
                  onSelected: (_) => setState(() => category = c)))),
          ]),
          TextField(controller: descCtrl, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description')),
          OutlinedButton.icon(
            onPressed: uploadingPhoto ? null : () async {
              setState(() { uploadingPhoto = true; error = ''; });
              try {
                final picked =
                  await CloudinaryService().pickRequestPhoto();
                if (mounted && picked != null) {
                  setState(() => photoUrl = picked.url);
                }
              } catch (e) {
                if (mounted) setState(() => error = 'Photo upload failed: $e');
              } finally {
                if (mounted) setState(() => uploadingPhoto = false);
              }
            },
            icon: uploadingPhoto
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt),
            label: Text(uploadingPhoto ? 'Uploading…'
              : photoUrl != null ? 'Photo attached ✓ (tap to change)' : 'Attach Photo (optional)')),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const Text('Submitted > In Progress > Resolved',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              // submits ticket then closes sheet and shows confirmation message
              onPressed: (titleCtrl.text.isEmpty || isSubmitting || uploadingPhoto)
                ? null : () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                setState(() { isSubmitting = true; error = ''; });
                try {
                  await ColdmountService().submitTicket(
                    uid: widget.uid, tenant: widget.tenantName,
                    unit: widget.unit, title: titleCtrl.text.trim(),
                    category: category, description: descCtrl.text.trim(),
                    photoUrl: photoUrl);
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Request sent — the admin can now see it')));
                } catch (e) {
                  if (!mounted) return;
                  setState(() { isSubmitting = false; error = 'Submit failed: $e'; });
                }
              },
              child: Text(isSubmitting ? 'Submitting…' : 'Submit Request'))),
        ])),
    );
  }
}
