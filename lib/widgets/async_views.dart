// shared async state widgets for loading error and empty
import 'package:flutter/material.dart';
import 'common.dart';

// centered loading spinner shown during short async waiting periods
class CmLoading extends StatelessWidget {
  const CmLoading({super.key});
  @override
  Widget build(BuildContext context) =>
    const Center(child: CircularProgressIndicator());
}

// friendly error card explaining failure with optional technical details
class CmErrorCard extends StatelessWidget {
  final String title;
  final Object? error;
  const CmErrorCard({super.key, required this.title, this.error});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      CmCard(child: ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text(title),
        subtitle: Text('${error ?? 'Unknown error'}'))),
    ]);
  }
}

// gentle empty state card suggesting what tenant should do next
class CmEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const CmEmpty({super.key, required this.icon,
    required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return CmCard(child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle)));
  }
}
