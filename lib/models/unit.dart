// boarding unit model with rent status tenant and inspection details
// boarding room with floor rent tenant and inspection status
class Unit {
// unit code floor area size and occupancy related status fields
  final String id; final int floor, sqm;
  final String status, tenant, leaseEnd, dueStatus, lastInspection;
// monthly rent stored numerically for totals and peso display
  final double rent;
// optional cover photo url loaded from cloudinary image storage
  final String? imageUrl;
  const Unit({required this.id, required this.floor, required this.status,
    required this.tenant, required this.rent, required this.leaseEnd,
    required this.dueStatus, required this.sqm, required this.lastInspection,
    this.imageUrl});
// returns copy with updated image status and tenant only
  Unit copyWith({String? imageUrl, String? status, String? tenant}) => Unit(
    id: id, floor: floor, status: status ?? this.status,
    tenant: tenant ?? this.tenant, rent: rent, leaseEnd: leaseEnd,
    dueStatus: dueStatus, sqm: sqm, lastInspection: lastInspection,
    imageUrl: imageUrl ?? this.imageUrl);
}
