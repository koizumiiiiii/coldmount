// Dev-only Firestore backup tool. NOT part of the shipped app.
//
// Reads every collection with your admin login (normal Firestore reads,
// inside the free quota) and writes one JSON file. No Blaze plan needed.
//
// RUN (from project root, password stays on your machine):
//   flutter run -d windows --target lib/tools/firestore_dump.dart \
//     --dart-define=ADMIN_EMAIL=you@example.com \
//     --dart-define=ADMIN_PASS=yourpassword
//
// OUTPUT: firestore_backup_<timestamp>.json in the project root.
// NEVER commit that file (it holds real user data, already gitignored).
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

// every collection currently in the coldmount database
const _collections = <String>[
  'users',
  'units',
  'leases',
  'payments',
  'tickets',
  'violations',
  'refunds',
  'utility_payments',
  'announcements',
];

const _email = String.fromEnvironment('ADMIN_EMAIL');
const _pass = String.fromEnvironment('ADMIN_PASS');

// converts firestore types to plain json-safe values
Object? _encode(Object? value) {
  if (value is Timestamp) {
    return {'__timestamp': value.toDate().toIso8601String()};
  }
  if (value is GeoPoint) {
    return {'__geopoint': <double>[value.latitude, value.longitude]};
  }
  if (value is DocumentReference) {
    return {'__ref': value.path};
  }
  if (value is Blob) {
    return {'__blob': base64Encode(value.bytes)};
  }
  if (value is Map) {
    return <String, Object?>{for (final e in value.entries) '${e.key}': _encode(e.value)};
  }
  if (value is List) {
    return <Object?>[for (final e in value) _encode(e)];
  }
  return value;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(_email.isNotEmpty, 'Pass --dart-define=ADMIN_EMAIL=...');
  assert(_pass.isNotEmpty, 'Pass --dart-define=ADMIN_PASS=...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: _email,
    password: _pass,
  );

  final db = FirebaseFirestore.instance;
  final out = <String, Object?>{};
  for (final col in _collections) {
    final snap = await db.collection(col).get();
    out[col] = <String, Object?>{
      for (final d in snap.docs) d.id: _encode(d.data()),
    };
    stdout.writeln('$col: ${snap.docs.length} docs');
  }

  final stamp =
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  final file = File('firestore_backup_$stamp.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(out),
  );
  stdout.writeln('WROTE ${file.absolute.path}');

  await FirebaseAuth.instance.signOut();
  exit(0);
}
