import 'package:cloud_firestore/cloud_firestore.dart';

class ColdmountService {
  final CollectionReference units =
      FirebaseFirestore.instance.collection('units');

  // creates new vacant rental unit with details in firestore
  Future<void> addUnit({
    required String unitNo,
    required int floor,
    required double rent,
    required int sqm,
    String? imageUrl,
  }) {
    return units.add({
      'unitNo': unitNo,
      'floor': floor,
      'rent': rent,
      'sqm': sqm,
      'status': 'vacant',
      'tenant': '',
      'image_url': imageUrl,
      'createdAt': Timestamp.now(),
    });
  }

  // creates new rental unit directly from given map data
  Future<void> addUnitMap(Map<String, dynamic> data) {
    return units.add({...data, 'createdAt': Timestamp.now()});
  }

  // streams all rental units ordered by newest creation date
  Stream<QuerySnapshot> getUnits() {
    return units.orderBy('createdAt', descending: true).snapshots();
  }

  // links tenant account to chosen unit and marks occupied
  Future<void> assignTenantToUnit({
    required String unitNo,
    required String tenantName,
    required String tenantUid,
  }) async {
    final q = await units.where('unitNo', isEqualTo: unitNo).limit(1).get();
    if (q.docs.isEmpty) {
      await units.add({
        'unitNo': unitNo,
        'floor': 1,
        'rent': 5500.0,
        'sqm': 22,
        'status': 'occupied',
        'tenant': tenantName,
        'tenantUid': tenantUid,
        'image_url': null,
        'createdAt': Timestamp.now(),
      });
    } else {
      await q.docs.first.reference.update({
        'status': 'occupied',
        'tenant': tenantName,
        'tenantUid': tenantUid,
      });
    }
  }

  // exposes firestore payments collection for rent transactions
  CollectionReference get payments =>
      FirebaseFirestore.instance.collection('payments');

  // submits tenant rent payment as pending for admin verification
  Future<void> submitRentPayment({
    required String uid,
    required String tenantName,
    required String unit,
    required String month,
    required double amount,
    required String method,
  }) {
    return payments.add({
      'uid': uid,
      'tenant': tenantName,
      'unit': unit,
      'month': month,
      'amount': amount,
      'method': method,
      'status': 'pending',
      'receipt': '',
      'note': method == 'Cash' ? 'Waiting for admin confirmation' : '',
      'createdAt': Timestamp.now(),
    });
  }

  // records verified admin confirmed payment with receipt details
  Future<void> recordPayment({
    required String uid,
    required String tenant,
    required String unit,
    required String month,
    required int year,
    required int monthIndex,
    required double amount,
    required String method,
    required String receipt,
  }) {
    return payments.add({
      'uid': uid,
      'tenant': tenant,
      'unit': unit,
      'month': month,
      'year': year,
      'monthIndex': monthIndex,
      'amount': amount,
      'method': method,
      'status': 'verified',
      'receipt': receipt,
      'note': 'Recorded by admin',
      'createdAt': Timestamp.now(),
    });
  }

  // streams all rent payments regardless of verification status
  Stream<QuerySnapshot> getAllPayments() {
    return payments.snapshots();
  }

  // streams rent payments belonging to one specific tenant user
  Stream<QuerySnapshot> getTenantPayments(String uid) {
    return payments.where('uid', isEqualTo: uid).snapshots();
  }

  // streams rent payments waiting for admin verification approval
  Stream<QuerySnapshot> getPendingPayments() {
    return payments.where('status', isEqualTo: 'pending').snapshots();
  }

  // streams rent payments already verified by the admin
  Stream<QuerySnapshot> getVerifiedPayments() {
    return payments.where('status', isEqualTo: 'verified').snapshots();
  }

  // sorts firestore documents from newest to oldest creation time
  static List<QueryDocumentSnapshot> sortByCreatedDesc(
      List<QueryDocumentSnapshot> docs) {
    int ts(QueryDocumentSnapshot d) {
      final v = (d.data() as Map<String, dynamic>)['createdAt'];
      return v is Timestamp ? v.millisecondsSinceEpoch : 0;
    }
    return [...docs]..sort((a, b) => ts(b).compareTo(ts(a)));
  }

  // marks payment document verified and attaches receipt reference
  Future<void> verifyPaymentDoc(String id, String receipt,
      {int? year, int? monthIndex}) {
    final Map<String, dynamic> data = {'status': 'verified', 'receipt': receipt};
    if (year != null) data['year'] = year;
    if (monthIndex != null) data['monthIndex'] = monthIndex;
    return payments.doc(id).update(data);
  }

  // marks payment document rejected with given reason note
  Future<void> rejectPaymentDoc(String id, String reason) {
    return payments.doc(id).update({'status': 'rejected', 'note': reason});
  }

  // streams all user accounts having the tenant role only
  Stream<QuerySnapshot> getTenants() {
    return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'tenant')
      .snapshots();
  }

  // streams all registered user accounts in the system
  Stream<QuerySnapshot> getUsers() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  // removes tenant account and frees the assigned rental unit
  Future<void> removeTenant({required String uid, required String unitNo}) async {
    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(uid).delete();
    await releaseUnitsOf(uid, unitNo: unitNo);
  }

  // frees occupied units linked to tenant id or unit number
  Future<void> releaseUnitsOf(String uid, {String unitNo = ''}) async {
    final seen = <String>{};
    if (uid.isNotEmpty) {
      final byUid = await units.where('tenantUid', isEqualTo: uid).get();
      for (final doc in byUid.docs) {
        if (seen.add(doc.id)) {
          await doc.reference.update({
            'status': 'vacant', 'tenant': '', 'tenantUid': '',
          });
        }
      }
    }
    if (unitNo.isNotEmpty) {
      final byNo =
        await units.where('unitNo', isEqualTo: unitNo).limit(1).get();
      for (final doc in byNo.docs) {
        if (seen.add(doc.id)) {
          await doc.reference.update({
            'status': 'vacant', 'tenant': '', 'tenantUid': '',
          });
        }
      }
    }
  }

  // exposes firestore leases collection for contract documents
  CollectionReference get leases =>
      FirebaseFirestore.instance.collection('leases');

  // creates new lease contract document with timestamp in firestore
  Future<void> createLease(Map<String, dynamic> data) {
    return leases.add({...data, 'createdAt': Timestamp.now()});
  }

  // streams active lease contract belonging to specific tenant user
  Stream<QuerySnapshot> getTenantLease(String uid) {
    return leases
      .where('uid', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots();
  }

  // streams all lease contracts ordered by newest creation date
  Stream<QuerySnapshot> getAllLeases() {
    return leases.orderBy('createdAt', descending: true).snapshots();
  }

  // approves lease renewal with updated rent and active status
  Future<void> approveRenewalDoc(String id, double newRent) {
    return leases.doc(id).update({'rent': newRent, 'status': 'active'});
  }

  // updates fields of existing lease document by identifier
  Future<void> updateLeaseDoc(String id, Map<String, dynamic> data) {
    return leases.doc(id).update(data);
  }

  // saves tenant conforme signature details onto lease document
  Future<void> signConforme({
    required String leaseId,
    required String tenantName,
  }) {
    return leases.doc(leaseId).update({
      'conformeSigned': true,
      'conformeBy': tenantName,
      'conformeAt': Timestamp.now(),
    });
  }

  // ends active lease while keeping it as history record
  Future<void> endLease(String id) {
    return leases.doc(id).update({'status': 'ended'});
  }

  // deletes lease document permanently from firestore collection
  Future<void> deleteLease(String id) {
    return leases.doc(id).delete();
  }

  // exposes firestore tickets collection for maintenance requests
  CollectionReference get tickets =>
      FirebaseFirestore.instance.collection('tickets');

  // files new tenant maintenance ticket with optional photo link
  Future<void> submitTicket({
    required String uid,
    required String tenant,
    required String unit,
    required String title,
    required String category,
    required String description,
    String? photoUrl,
  }) {
    return tickets.add({
      'uid': uid,
      'tenant': tenant,
      'unit': unit,
      'title': title,
      'category': category,
      'description': description,
      'photo_url': photoUrl ?? '',
      'status': 'submitted',
      'assignee': '',
      'createdAt': Timestamp.now(),
      'resolvedAt': null,
    });
  }

  // streams maintenance tickets filed by one specific tenant
  Stream<QuerySnapshot> getTenantTickets(String uid) {
    return tickets.where('uid', isEqualTo: uid).snapshots();
  }

  // streams all maintenance tickets from every tenant user
  Stream<QuerySnapshot> getAllTickets() {
    return tickets.snapshots();
  }

  // marks ticket in progress and assigns caretaker for handling
  Future<void> startTicket(String id, {String assignee = 'Caretaker'}) {
    return tickets.doc(id).update({
      'status': 'in-progress', 'assignee': assignee,
    });
  }

  // marks ticket resolved and stamps current resolution time
  Future<void> resolveTicket(String id) {
    return tickets.doc(id).update({
      'status': 'resolved', 'resolvedAt': Timestamp.now(),
    });
  }
  // exposes firestore violations collection for rule infraction logs
  CollectionReference get violations =>
      FirebaseFirestore.instance.collection('violations');

  // logs new admin noted violation against tenant and unit
  Future<void> logViolation({
    required String tenantUid,
    required String tenant,
    required String unit,
    required String title,
    required String severity,
    required String notes,
  }) {
    return violations.add({
      'tenantUid': tenantUid,
      'tenant': tenant,
      'unit': unit,
      'title': title,
      'severity': severity,
      'status': 'noted',
      'notes': notes,
      'date': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
  }

  // streams all recorded tenant violations across all units
  Stream<QuerySnapshot> getAllViolations() {
    return violations.snapshots();
  }

  // streams violations recorded against one specific tenant user
  Stream<QuerySnapshot> getTenantViolations(String uid) {
    return violations.where('tenantUid', isEqualTo: uid).snapshots();
  }

  // deletes violation log permanently from firestore collection
  Future<void> deleteViolation(String id) {
    return violations.doc(id).delete();
  }

  // exposes firestore refunds collection for move out settlements
  CollectionReference get refunds =>
      FirebaseFirestore.instance.collection('refunds');

  // saves move out refund record with deductions and total
  Future<void> recordRefund({
    required String uid,
    required String tenant,
    required String unit,
    required double security,
    required List<Map<String, dynamic>> deductions,
    required double refund,
  }) {
    return refunds.add({
      'uid': uid,
      'tenant': tenant,
      'unit': unit,
      'security': security,
      'deductions': deductions,
      'deductionsTotal':
        deductions.fold<double>(0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0)),
      'refund': refund,
      'status': 'recorded',
      'createdAt': Timestamp.now(),
    });
  }

  // streams refund records belonging to one specific tenant user
  Stream<QuerySnapshot> getTenantRefunds(String uid) {
    return refunds.where('uid', isEqualTo: uid).snapshots();
  }
  // exposes utility payments collection for tenant bill records
  CollectionReference get utilityPayments =>
      FirebaseFirestore.instance.collection('utility_payments');

  // records tenant utility bill payment as recorded with details
  Future<void> recordUtilityPayment({
    required String uid,
    required String tenant,
    required String unit,
    required String billType,
    required String period,
    required double amount,
    required String method,
  }) {
    return utilityPayments.add({
      'uid': uid,
      'tenant': tenant,
      'unit': unit,
      'billType': billType,
      'period': period,
      'amount': amount,
      'method': method,
      'status': 'recorded',
      'createdAt': Timestamp.now(),
    });
  }
  // exposes announcements collection for community notice posts
  CollectionReference get announcements =>
      FirebaseFirestore.instance.collection('announcements');

  // posts new admin announcement visible to all community members
  Future<void> postAnnouncement({
    required String title,
    required String body,
    String type = 'info',
  }) {
    return announcements.add({
      'title': title,
      'body': body,
      'type': type,
      'date': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
  }

  // streams announcements ordered newest first with optional limit
  Stream<QuerySnapshot> getAnnouncements({int? limit}) {
    Query q = announcements.orderBy('createdAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  // deletes announcement permanently from firestore collection store
  Future<void> deleteAnnouncement(String id) {
    return announcements.doc(id).delete();
  }

  // updates fields of existing rental unit by document identifier
  Future<void> updateUnit(String id, Map<String, dynamic> data) {
    return units.doc(id).update(data);
  }

  // deletes vacant unit only and blocks occupied unit deletion
  Future<void> deleteUnit(String id) async {
    final doc = await units.doc(id).get();
    final m = doc.data() as Map<String, dynamic>?;
    if ((m?['status'] as String?) == 'occupied') {
      throw StateError('cannot delete occupied unit');
    }
    return units.doc(id).delete();
  }
}
