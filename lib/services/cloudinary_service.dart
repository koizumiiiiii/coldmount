import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final Uint8List bytes;
  final String url;
  PickedImage({required this.bytes, required this.url});
}

class CloudinaryService {
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    'b7znabwh',
    'flutter_notes_preset',
    cache: false,
  );
  final ImagePicker _picker = ImagePicker();

  // picks unit photo from gallery and uploads to cloudinary
  Future<PickedImage?> pickUnitImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    // reads image bytes so upload works on web and mobile
    final bytes = await picked.readAsBytes();
    final res = await _cloudinary.uploadFile(
      CloudinaryFile.fromBytesData(
        bytes,
        identifier: picked.name,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return PickedImage(bytes: bytes, url: res.secureUrl);
  }

  // picks maintenance request photo using same upload flow
  Future<PickedImage?> pickRequestPhoto() => pickUnitImage();
}
