import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PreparedEvidencePhoto {
  const PreparedEvidencePhoto({
    required this.bytes,
    required this.filename,
    required this.sizeBytes,
  });

  final Uint8List bytes;
  final String filename;
  final int sizeBytes;
}

/// Pengambilan & kompresi bukti foto K3 ISO 45001 (SRS-EIF-006 & SRS-SEC-011):
/// - Android: Kamera / Galeri (kompres <= 1280px, kualitas 75%, keepExif: false)
/// - Desktop (Linux/Windows): FilePicker gambar (batas keras <= 2 MB)
class EvidenceImageHelper {
  static const int maxHardBytes = 2 * 1024 * 1024; // 2 MB

  static Future<PreparedEvidencePhoto?> pickEvidencePhoto({
    required bool fromCamera,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked == null) return null;

      final tmpDir = await getTemporaryDirectory();
      final targetPath =
          '${tmpDir.path}/hti_ev_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Kompresi otomatis & penghapusan EXIF/GPS di sisi klien (keepExif: false)
      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
        keepExif: false,
      );

      final Uint8List bytes = compressed != null
          ? await compressed.readAsBytes()
          : await picked.readAsBytes();

      if (bytes.length > maxHardBytes) {
        throw Exception('Ukuran foto setelah kompresi masih melebihi batas 2 MB.');
      }
      return PreparedEvidencePhoto(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'evidence.jpg',
        sizeBytes: bytes.length,
      );
    }

    // Desktop Windows / Linux file dialog
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return null;
    if (bytes.length > maxHardBytes) {
      throw Exception('Ukuran berkas gambar melebihi batas maksimal 2 MB.');
    }
    return PreparedEvidencePhoto(
      bytes: bytes,
      filename: file.name,
      sizeBytes: bytes.length,
    );
  }
}
