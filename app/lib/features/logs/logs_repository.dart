import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class StockQtySnapshot {
  const StockQtySnapshot({
    required this.good,
    required this.service,
    required this.broken,
    required this.inTransit,
  });

  final int good;
  final int service;
  final int broken;
  final int inTransit;

  static StockQtySnapshot? tryFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return StockQtySnapshot(
      good: (raw['good'] as num?)?.toInt() ?? 0,
      service: (raw['service'] as num?)?.toInt() ?? 0,
      broken: (raw['broken'] as num?)?.toInt() ?? 0,
      inTransit: (raw['in_transit'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockLogEntry {
  const StockLogEntry({
    required this.id,
    required this.itemCode,
    required this.itemDescription,
    required this.actionType,
    this.statusChanged,
    required this.qtyChanged,
    this.qtyBefore,
    this.qtyAfter,
    this.fromLocationName,
    this.toLocationName,
    this.jobCode,
    this.note,
    this.photoUrl,
    this.userName,
    required this.createdAt,
  });

  final int id;
  final String itemCode;
  final String itemDescription;
  final String actionType;
  final String? statusChanged;
  final int qtyChanged;
  final StockQtySnapshot? qtyBefore;
  final StockQtySnapshot? qtyAfter;
  final String? fromLocationName;
  final String? toLocationName;
  final String? jobCode;
  final String? note;
  final String? photoUrl;
  final String? userName;
  final DateTime createdAt;

  /// Merangkai ringkasan selisih saldo sebelum → sesudah untuk audit cepat ISO 9001
  String? get snapshotDiffSummary {
    final before = qtyBefore;
    final after = qtyAfter;
    if (after == null) return null;
    if (before == null) {
      return 'Saldo Awal: Good ${after.good}, Service ${after.service}, Broken ${after.broken}';
    }
    final diffs = <String>[];
    if (before.good != after.good) diffs.add('Good: ${before.good}→${after.good}');
    if (before.service != after.service) diffs.add('Service: ${before.service}→${after.service}');
    if (before.broken != after.broken) diffs.add('Broken: ${before.broken}→${after.broken}');
    if (before.inTransit != after.inTransit) {
      diffs.add('In-Transit: ${before.inTransit}→${after.inTransit}');
    }
    return diffs.isEmpty ? null : diffs.join(' • ');
  }

  factory StockLogEntry.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    final fromLoc = json['fromLocation'] as Map<String, dynamic>?;
    final toLoc = json['toLocation'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return StockLogEntry(
      id: (json['id'] as num).toInt(),
      itemCode: (item?['itemCode'] as String?) ?? '-',
      itemDescription: (item?['description'] as String?) ?? '-',
      actionType: json['actionType'] as String,
      statusChanged: json['statusChanged'] as String?,
      qtyChanged: (json['qtyChanged'] as num).toInt(),
      qtyBefore: StockQtySnapshot.tryFromJson(json['qtyBefore']),
      qtyAfter: StockQtySnapshot.tryFromJson(json['qtyAfter']),
      fromLocationName: fromLoc?['name'] as String?,
      toLocationName: toLoc?['name'] as String?,
      jobCode: json['jobCode'] as String?,
      note: json['note'] as String?,
      photoUrl: json['photoUrl'] as String?,
      userName: user?['fullName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class PagedLogsResult {
  const PagedLogsResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<StockLogEntry> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

class LogsFilter {
  const LogsFilter({
    this.actionType,
    this.locationId,
    this.dateFrom,
    this.dateTo,
    this.page = 1,
  });

  final String? actionType;
  final int? locationId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;

  LogsFilter copyWith({
    String? Function()? actionType,
    int? Function()? locationId,
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    int? page,
  }) {
    return LogsFilter(
      actionType: actionType != null ? actionType() : this.actionType,
      locationId: locationId != null ? locationId() : this.locationId,
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      page: page ?? this.page,
    );
  }
}

String _formatIsoDateOnly(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class LogsRepository {
  const LogsRepository(this._dio);

  final Dio _dio;

  Future<PagedLogsResult> fetchLogs({
    int? locationId,
    String? actionType,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/logs',
        queryParameters: {
          'locationId': ?locationId,
          if (actionType != null && actionType.isNotEmpty) 'actionType': actionType,
          if (dateFrom != null) 'dateFrom': _formatIsoDateOnly(dateFrom),
          if (dateTo != null) 'dateTo': _formatIsoDateOnly(dateTo),
          'page': page,
          'limit': limit,
        },
      );
      final list = (res.data!['data'] as List<dynamic>)
          .map((e) => StockLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = (res.data!['meta'] as Map<String, dynamic>?) ?? {};
      return PagedLogsResult(
        items: list,
        page: (meta['page'] as num?)?.toInt() ?? page,
        limit: (meta['limit'] as num?)?.toInt() ?? limit,
        total: (meta['total'] as num?)?.toInt() ?? list.length,
        totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Mengambil foto bukti K3 melalui endpoint ber-JWT (SRS-SEC-008)
  Future<Uint8List> fetchProtectedPhotoBytes(String photoUrl) async {
    try {
      final res = await _dio.get<List<int>>(
        photoUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Ekspor laporan Excel/PDF ISO 9001 dan simpan ke berkas lokal OS (IF-FS-EXPORT)
  Future<String?> downloadAndSaveReport({
    required String type,
    required String format,
    int? locationId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/v1/reports/export',
        queryParameters: {
          'type': type,
          'format': format,
          'locationId': ?locationId,
          if (dateFrom != null) 'dateFrom': _formatIsoDateOnly(dateFrom),
          if (dateTo != null) 'dateTo': _formatIsoDateOnly(dateTo),
        },
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(res.data!);
      final dateTag = DateTime.now().toIso8601String().substring(0, 10);
      final suggestedName = 'HTI_${type == 'stock' ? 'Inventory' : 'ISO9001_Logs'}_$dateTag.$format';

      if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan Laporan PT HTI',
          fileName: suggestedName,
        );
        if (savePath == null) return null;
        await File(savePath).writeAsBytes(bytes);
        return savePath;
      }

      final dir = await getApplicationDocumentsDirectory();
      final outFile = File('${dir.path}/$suggestedName');
      await outFile.writeAsBytes(bytes);
      return outFile.path;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final logsRepositoryProvider = Provider<LogsRepository>((ref) {
  return LogsRepository(ref.watch(dioProvider));
});

final logsFilterProvider = StateProvider<LogsFilter>((ref) => const LogsFilter());

final auditLogsProvider = FutureProvider<PagedLogsResult>((ref) {
  final filter = ref.watch(logsFilterProvider);
  return ref.watch(logsRepositoryProvider).fetchLogs(
        locationId: filter.locationId,
        actionType: filter.actionType,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
        page: filter.page,
      );
});
