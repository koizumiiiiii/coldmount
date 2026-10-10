// shared small widgets for badges avatars cards and labels
import 'package:flutter/material.dart';
import '../core/theme.dart';

// picks badge color matching given payment or occupancy status
Color badgeColor(String kind) {
  switch (kind) {
    case 'paid': case 'verified': case 'resolved': case 'active':
      return Colors.green;
    case 'occupied': case 'in-progress':
      return Colors.blue;
    case 'pending': case 'minor': case 'cash-pending': case 'submitted':
      return Colors.amber.shade800;
    case 'expiring-soon': case 'warning':
      return Colors.orange.shade800;
    case 'overdue': case 'major': case 'rejected':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

// small pill badge showing status with matching tinted color
class CmBadge extends StatelessWidget {
  final String label; final String kind;
  const CmBadge({super.key, required this.label, required this.kind});
  @override
  Widget build(BuildContext context) {
    final c = badgeColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(25), borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

// circular avatar showing tenant initials on colored background
class Avatar extends StatelessWidget {
  final String name; final double size;
  const Avatar({super.key, required this.name, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').map((e) => e.isEmpty ? '' : e[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: size / 2, backgroundColor: CmColors.primary,
      child: Text(initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
  }
}

// rounded white card wrapping content with soft outer padding
class CmCard extends StatelessWidget {
  final Widget child; final EdgeInsets padding;
  const CmCard({super.key, required this.child,
    this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: padding, child: child),
    );
  }
}

// small uppercase label separating content into clear readable sections
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel({super.key, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          letterSpacing: 1.2, color: Colors.grey.shade600)),
    );
  }
}
