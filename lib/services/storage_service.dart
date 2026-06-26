import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ImageUploadResult {
  const ImageUploadResult({
    required this.url,
    required this.path,
  });

  final String url;
  final String path;
}

class StorageService {
  static const String _cloudName = 'dijswvhab';
  static const String _apiKey = '786533456125142';
  static const String _uploadPreset = 'pocket_app';

  Future<ImageUploadResult> uploadEntryImage({
    required String uid,
    required String entryId,
    required File file,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = _apiKey
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'pocketstory/users/$uid/entries'
      ..fields['public_id'] = entryId
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload ảnh thất bại: $responseBody');
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    final imageUrl = data['secure_url'] as String?;
    final imagePath = data['public_id'] as String?;

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Cloudinary không trả về URL ảnh');
    }

    return ImageUploadResult(
      url: imageUrl,
      path: imagePath ?? 'pocketstory/users/$uid/entries/$entryId',
    );
  }

  Future<void> deleteEntryImage(String? path) async {
    if (path == null || path.isEmpty) return;

    // Project đang dùng unsigned upload preset của Cloudinary. Xóa ảnh trực tiếp
    // từ client cần API secret nên không nên đặt trong app Flutter. Hiện tại
    // hàm này đóng vai trò điểm mở rộng để sau này chuyển việc xóa ảnh sang
    // Cloud Functions hoặc backend riêng.
  }
}
