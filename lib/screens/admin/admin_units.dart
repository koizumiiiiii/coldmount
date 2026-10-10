import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/cloudinary_service.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// units grid that streams firestore and shows occupancy cards
class AdminUnits extends StatefulWidget {
  const AdminUnits({super.key});
  @override
  State<AdminUnits> createState() => _AdminUnitsState();
}

// units state that heals orphan units and builds cards
class _AdminUnitsState extends State<AdminUnits> {
  final _svc = ColdmountService();
  final Set<String> _healedUnits = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.getUnits(),
      builder: (context, snap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _svc.getTenants(),
          builder: (context, tenantSnap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const CmLoading();
      }
      if (snap.hasError) {
        return CmErrorCard(
          title: 'Could not load units', error: snap.error);
      }
      final docs = snap.data?.docs ?? [];
      final liveUids = <String>{
        for (final t in tenantSnap.data?.docs ?? []) t.id,
      };
      // detect orphan units without user document and mark them vacant
      final orphanIds = <String>{};
      for (final d in docs) {
        final m = d.data() as Map<String, dynamic>;
        final tUid = (m['tenantUid'] as String?) ?? '';
        if (tUid.isNotEmpty && !liveUids.contains(tUid)) {
          orphanIds.add(d.id);
        }
      }
      // release orphan units once so vacant status stays consistent
      for (final d in docs.where((d) => orphanIds.contains(d.id))) {
        final u = d.data() as Map<String, dynamic>;
        if (_healedUnits.add(d.id)) {
          _svc.releaseUnitsOf('${u['tenantUid'] ?? ''}',
            unitNo: '${u['unitNo'] ?? ''}');
        }
      }
      final cards = <Widget>[];
      for (final d in docs) {
        final m = d.data() as Map<String, dynamic>;
        final orphan = orphanIds.contains(d.id);
        final img = m['image_url'] as String?;
        final tenant = orphan ? '' : ((m['tenant'] as String?) ?? '');
        final status =
          orphan ? 'vacant' : ((m['status'] as String?) ?? 'vacant');
        final no = (m['unitNo'] as String?) ?? '';
        final rent = ((m['rent'] as num?)?.toDouble() ?? 0);
        final sqm = m['sqm'] ?? '?';
        cards.add(
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UnitDetailScreen(
                    docId: d.id,
                    data: m,
                    vacant: orphan ? true : status == 'vacant',
                  ),
                ),
              );
            },
            child: CmCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: img != null && img.isNotEmpty
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (c, e, s) =>
                              _unitPlaceholder(no, status),
                          )
                        : _unitPlaceholder(no, status),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unit $no — ${tenant.isEmpty ? 'VACANT' : tenant}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '${peso(rent)}/mo · $sqm sqm',
                    style: const TextStyle(fontSize: 11),
                  ),
                  CmBadge(label: status, kind: status),
                ],
              ),
            ),
          ),
        );
      }
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${docs.length} unit${docs.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          ElevatedButton.icon(onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddUnitScreen())),
            icon: const Icon(Icons.add, size: 16), label: const Text('Add')),
        ]),
        const SizedBox(height: 8),
        if (docs.isEmpty)
          const CmCard(child: ListTile(
            leading: Icon(Icons.apartment),
            title: Text('No units yet'),
            subtitle: Text('Tap Add to register your first unit with a photo.'))),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: cards,
        ),
      ]);
          },
        );
      },
    );
  }

  // builds placeholder tile with unit number and status color
  Widget _unitPlaceholder(String no, String status) => Container(
    width: double.infinity, color: status == 'occupied'
      ? CmColors.primary : Colors.grey.shade200,
    child: Center(child: Text(no,
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
        color: status == 'occupied' ? Colors.white : Colors.grey))));
}

// add unit form that collects number rent and photo
class AddUnitScreen extends StatefulWidget {
  const AddUnitScreen({super.key});
  @override
  State<AddUnitScreen> createState() => _AddUnitScreenState();
}

// add unit state that uploads photo and saves unit
class _AddUnitScreenState extends State<AddUnitScreen> {
  final noCtrl = TextEditingController();
  final sqmCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  String floor = '1';
  Uint8List? photoBytes;
  String? photoUrl;
  bool uploading = false;
  bool isSaving = false;
  final svc = CloudinaryService();

  // picks gallery photo and uploads image to cloudinary storage
  Future<void> pickPhoto() async {
    setState(() => uploading = true);
    try {
      final picked = await svc.pickUnitImage();
      if (picked != null && mounted) {
        setState(() { photoBytes = picked.bytes; photoUrl = picked.url; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded to Cloudinary')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = noCtrl.text.isNotEmpty && rentCtrl.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Unit')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CmCard(child: Column(children: [
          TextField(controller: noCtrl,
            decoration: const InputDecoration(labelText: 'Unit Number (e.g. 203)'),
            onChanged: (_) => setState(() {})),
          TextField(controller: sqmCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Floor Area (sqm)')),
          TextField(controller: rentCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monthly Rent (₱)'),
            onChanged: (_) => setState(() {})),
          Row(children: [
            for (final f in ['1', '2'])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(f == '1' ? 'Ground' : '2nd Floor'),
                  selected: floor == f,
                  onSelected: (_) => setState(() => floor = f)))),
          ]),
        ])),
        CmCard(child: Column(children: [
          const SectionLabel(label: 'Unit Photo — single, gallery only'),
          if (photoBytes != null)
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.memory(photoBytes!, height: 160, fit: BoxFit.cover)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : pickPhoto,
              icon: uploading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
              label: Text(uploading ? 'Uploading…' : 'Upload Image'))),
          if (photoUrl != null)
            const Text('Uploaded ✓ — URL saved with unit',
              style: TextStyle(fontSize: 11, color: Colors.green)),
        ])),
        // saves new unit to firestore with photo url
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CmColors.accent, foregroundColor: Colors.white),
            onPressed: (!valid || isSaving) ? null : () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              setState(() => isSaving = true);
              try {
                await ColdmountService().addUnit(
                  unitNo: noCtrl.text,
                  floor: int.parse(floor),
                  rent: double.tryParse(rentCtrl.text) ?? 5500,
                  sqm: int.tryParse(sqmCtrl.text) ?? 22,
                  imageUrl: photoUrl,
                );
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                setState(() => isSaving = false);
                messenger.showSnackBar(
                  SnackBar(content: Text('Save failed: $e')));
              }
            },
            child: Text(isSaving ? 'Saving…' : 'Add Unit to Property'))),
      ]),
    );
  }
}

// unit detail screen that shows tenant and allows vacant delete
class UnitDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool vacant;
  const UnitDetailScreen(
      {super.key,
      required this.docId,
      required this.data,
      required this.vacant});
  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

// detail state that tracks delete working indicator flag
class _UnitDetailScreenState extends State<UnitDetailScreen> {
  bool working = false;

  // confirms deletion then removes vacant unit and closes
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('delete unit'),
        content: Text(
            'delete unit ${widget.data['unitNo']}? only vacant units can be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('delete', style: TextStyle(color: Colors.red))),
        ],
      ));
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => working = true);
    try {
      await ColdmountService().deleteUnit(widget.docId);
      navigator.pop();
      messenger.showSnackBar(
          SnackBar(content: Text('unit ${widget.data['unitNo']} deleted')));
    } on StateError {
      if (!mounted) return;
      setState(() => working = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('occupied unit cannot be deleted')));
    } catch (e) {
      if (!mounted) return;
      setState(() => working = false);
      messenger.showSnackBar(SnackBar(content: Text('delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.data['image_url'] as String?;
    final tenant = widget.vacant ? '' : ((widget.data['tenant'] as String?) ?? '');
    final status = widget.vacant
        ? 'vacant'
        : ((widget.data['status'] as String?) ?? 'vacant');
    return Scaffold(
      appBar: AppBar(title: Text('Unit ${widget.data['unitNo']} — Detail')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (img != null && img.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.network(img, height: 200, fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                Container(height: 120, color: Colors.grey.shade200,
                  child: const Icon(Icons.apartment, size: 48)))),
        CmCard(child: ListTile(
          title: Text(tenant.isEmpty ? 'Vacant' : tenant),
          subtitle: Text('${widget.data['sqm'] ?? '?'} sqm · Floor ${widget.data['floor'] ?? '?'} · ${peso((widget.data['rent'] as num?)?.toDouble() ?? 0)}/mo'),
          trailing: CmBadge(label: status, kind: status))),
        const CmCard(child: Column(children: [
          Text('Safety Inspection Log'),
          ListTile(title: Text('Aug 1, 2025 — Passed'),
            subtitle: Text('Smoke detector functional. Extinguisher full charge.')),
        ])),
        const SizedBox(height: 8),
        if (widget.vacant)
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: working ? null : _delete,
              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
              label: Text(working ? 'deleting…' : 'delete unit',
                style: const TextStyle(color: Colors.red)))),
        if (!widget.vacant)
          const CmCard(child: ListTile(
            leading: Icon(Icons.lock, color: Colors.grey),
            title: Text('occupied — cannot delete',
              style: TextStyle(fontSize: 12)),
            subtitle: Text('remove tenant first to free the unit',
              style: TextStyle(fontSize: 11)),
            dense: true)),
      ]),
    );
  }
}
