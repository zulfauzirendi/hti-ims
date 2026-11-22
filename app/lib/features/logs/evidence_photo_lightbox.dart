import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'logs_repository.dart';

/// Lightbox pembesaran (InteractiveViewer) untuk bukti foto K3 ISO 45001 ber-JWT (SRS-CAP-023)
class EvidencePhotoLightbox extends ConsumerWidget {
  const EvidencePhotoLightbox({
    super.key,
    required this.photoUrl,
    required this.title,
  });

  final String photoUrl;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: HtiColors.navyPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: HtiColors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bukti Foto K3 • $title',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: ref.read(logsRepositoryProvider).fetchProtectedPhotoBytes(photoUrl),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || !snap.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gagal memuat foto bukti: ${snap.error}',
                          style: const TextStyle(color: HtiColors.statusBroken),
                        ),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(child: Image.memory(snap.data!, fit: BoxFit.contain)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
