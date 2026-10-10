// user models holding tenant profile and admin list details
// detailed tenant profile with contact lease and emergency information
class TenantInfo {
// tenant identity contact occupancy move in and lease dates
  final String name, unit, floor, phone, email, occupation, moveIn, leaseEnd;
// rent advance security and occupant count for billing context
  final double rentAmount, advance, security;
  final int occupants;
// emergency contact name and phone for safety and notifications
  final String emergencyName, emergencyPhone;
  const TenantInfo({
    required this.name, required this.unit, required this.floor,
    required this.phone, required this.email, required this.occupation,
    required this.moveIn, required this.leaseEnd, required this.rentAmount,
    required this.advance, required this.security, required this.occupants,
    required this.emergencyName, required this.emergencyPhone,
  });
}

// tenant row for admin list with contact and payment status
class AdminTenant {
// admin list row with identity contact tenure and payment state
  final int id; final String name, unit, phone, email, since, payStatus, occupation;
  const AdminTenant({required this.id, required this.name, required this.unit,
    required this.phone, required this.email, required this.since,
    required this.payStatus, required this.occupation});
}
