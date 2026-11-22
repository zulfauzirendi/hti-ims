import 'package:flutter/material.dart';

/// Industrial PT HTI Design System & ISO 45001 High-Contrast K3 Status Palette
class HtiColors {
  static const Color navyPrimary = Color(0xFF0F2942);
  static const Color navySurface = Color(0xFF1E3A5F);
  static const Color amberAccent = Color(0xFFD97706);
  static const Color slateBg = Color(0xFFF8FAFC);

  // High-contrast K3 status colors (SRS-SAF-001 — selalu dipasangkan dengan ikon + label teks)
  static const Color statusGood = Color(0xFF2E7D32);
  static const Color statusService = Color(0xFFF57C00);
  static const Color statusBroken = Color(0xFFD32F2F);
  static const Color statusInTransit = Color(0xFF1565C0);
}

class HtiTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: HtiColors.navyPrimary,
      primary: HtiColors.navyPrimary,
      secondary: HtiColors.amberAccent,
      surface: Colors.white,
      error: HtiColors.statusBroken,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: HtiColors.slateBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: HtiColors.navyPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      // Target sentuh minimal 48x48dp untuk petugas lapangan (SRS-QAL-014)
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HtiColors.navyPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

/// Widget lencana status K3 ramah buta warna (warna + ikon + teks — SRS-SAF-001)
class ConditionStatusBadge extends StatelessWidget {
  const ConditionStatusBadge({
    super.key,
    required this.status,
    this.count,
  });

  final String status;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status.toUpperCase()) {
      'GOOD' => (HtiColors.statusGood, Icons.check_circle_outline, 'Good'),
      'SERVICE' => (HtiColors.statusService, Icons.build_circle_outlined, 'Service'),
      'BROKEN' => (HtiColors.statusBroken, Icons.warning_amber_rounded, 'Broken'),
      'IN_TRANSIT' => (HtiColors.statusInTransit, Icons.local_shipping_outlined, 'In-Transit'),
      _ => (Colors.blueGrey, Icons.info_outline, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            count != null ? '$label: $count' : label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
