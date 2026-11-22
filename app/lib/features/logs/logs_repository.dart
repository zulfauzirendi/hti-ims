import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class StockLogEntry {
  const StockLogEntry({
    required this.id,
    required this.itemCode,
    required this.itemDescription,
    required this.actionType,
    this.statusChanged,
    required this.qtyChanged,
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
  final String? fromLocationName;
  final String? toLocationName;
  final String? jobCode;
  final String? note;
  final String? photoUrl;
  final String? userName;
  final DateTime createdAt;

  factory StockLogEntry.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>;
    final fromLoc = json['fromLocation'] as Map<String, dynamic>?;
    final toLoc = json['toLocation'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return StockLogEntry(
      id: (json['id'] as num).toInt(),
      itemCode: item['itemCode'] as String,
      itemDescription: item['description'] as String,
      actionType: json['actionType'] as String,
      statusChanged: json['statusChanged'] as String?,
      qtyChanged: (json['qtyChanged'] as num).toInt(),
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

class LogsRepository {
  const LogsRepository(this._dio);

  final Dio _dio;

  Future<List<StockLogEntry>> fetchLogs({
    int? locationId,
    String? actionType,
    int page = 1,
    int limit = 40,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/logs',
        queryParameters: {
          'locationId': ?locationId,
          if (actionType != null && actionType.isNotEmpty) 'actionType': actionType,
          'page': page,
          'limit': limit,
        },
      );
      final list = res.data!['data'] as List<dynamic>;
      return list.map((e) => StockLogEntry.fromJson(e as Map<String, dynamic>)).toList();
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
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/v1/reports/export',
        queryParameters: {
          'type': type,
          'format': format,
          'locationId': ?locationId,
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

final logActionFilterProvider = StateProvider<String?>((ref) => null);
final logLocationFilterProvider = StateProvider<int?>((ref) => null);

final auditLogsProvider = FutureProvider<List<StockLogEntry>>((ref) {
  final action = ref.watch(logActionFilterProvider);
  final locId = ref.watch(logLocationFilterProvider);
  return ref.watch(logsRepositoryProvider).fetchLogs(locationId: locId, actionType: action);
});
