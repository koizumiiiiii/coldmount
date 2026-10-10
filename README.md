# Coldmount

**Author:** James Oliver C. Mendoza
**Subject:** CCE106/L AppDev (Mobile Development)

Boarding-house / tenant management Flutter app with Admin and Tenant roles — units, leases, payments, announcements, violations, and maintenance requests with photo uploads.

## Features

- Role-based login (admin / tenant)
- Admin: dashboard, tenants, units, leases, payments, announcements, maintenance
- Tenant: home, payments, lease, utilities/bills, maintenance requests, notifications, profile
- Photo uploads for units and maintenance via Cloudinary (unsigned preset)
- Firebase Auth + Cloud Firestore backend

## Tech Stack

- Flutter (Dart)
- Firebase Core, Firebase Auth, Cloud Firestore
- `cloudinary_public` + `image_picker`

## Getting Started

```bash
flutter pub get
flutter run
```

If Firebase is not configured on a fresh clone:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
flutter run
```

The committed `lib/firebase_options.dart` and `android/app/google-services.json` are public client-side configs and are required for the app to run.

## Roles

Roles are stored in Firestore at `users/{uid}` with field `role: admin | tenant`.

- Admin creates tenant accounts from inside the app (no self-registration).
- To make the first admin: create the user in Firebase Auth, then manually set `role: admin` in Firestore Console at `users/{uid}`.
- No admin email is hardcoded in source (intentionally, to avoid leaking personal accounts).

## Project Structure

```
lib/
  main.dart
  firebase_options.dart
  core/       # theme, utils
  models/     # user, unit, lease, payment, bill, ticket, etc.
  services/   # auth_service, coldmount_service, cloudinary_service
  screens/    # login, admin/, tenant/
  widgets/    # shared widgets
```

## Security Notes

- No passwords, private keys, or personal emails are committed in source.
- Do not commit `android/local.properties`, `*.pdf`, `*.jks` / `*.keystore`, or `.env` files (covered by `.gitignore`).
- Before going public: restrict Firebase API keys in Google Cloud Console (Android package + SHA-1) and lock down Firestore Security Rules.
