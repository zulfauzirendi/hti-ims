import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class StockTransferItem {
  const StockTransferItem({
    required this.id,
    required this.transferCode,
    required this.itemCode,
    required this.itemDescription,
    required this.itemUnit,
    required this.fromLocationId,
    required this.fromLocationCode,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationCode,
    required this.toLocationName,
    required this.conditionStatus,
    required this.qty,
    required this.status,
    required this.sentByName,
    this.receivedByName,
    this.jobCode,
    this.senderNote,
    this.receiverNote,
    required this.sentAt,
    this.resolvedAt,
  });

  final int id;
  final String transferCode;
  final String itemCode;
  final String itemDescription;
  final String itemUnit;
  final int fromLocationId;
  final String fromLocationCode;
  final String fromLocationName;
  final int toLocationId;
  final String toLocationCode;
  final String toLocationName;
  final String conditionStatus;
  final int qty;
  final String status;
  final String sentByName;
  final String? receivedByName;
  final String? jobCode;
  final String? senderNote;
  final String? receiverNote;
  final DateTime sentAt;
  final DateTime? resolvedAt;

  factory StockTransferItem.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>;
    final fromLoc = json['fromLocation'] as Map<String, dynamic>;
    final toLoc = json['toLocation'] as Map<String, dynamic>;
    final sentBy = json['sentBy'] as Map<String, dynamic>;
    final recvBy = json['receivedBy'] as Map<String, dynamic>?;
    return StockTransferItem(
      id: (json['id'] as num).toInt(),
      transferCode: json['transferCode'] as String,
      itemCode: item['itemCode'] as String,
      itemDescription: item['description'] as String,
      itemUnit: item['unit'] as String,
      fromLocationId: (fromLoc['id'] as num).toInt(),
      fromLocationCode: fromLoc['code'] as String,
      fromLocationName: fromLoc['name'] as String,
      toLocationId: (toLoc['id'] as num).toInt(),
      toLocationCode: toLoc['code'] as String,
      toLocationName: toLoc['name'] as String,
      conditionStatus: json['conditionStatus'] as String,
      qty: (json['qty'] as num).toInt(),
      status: json['status'] as String,
      sentByName: sentBy['fullName'] as String,
      receivedByName: recvBy?['fullName'] as String?,
      jobCode: json['jobCode'] as String?,
      senderNote: json['senderNote'] as String?,
      receiverNote: json['receiverNote'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt'] as String) : null,
    );
  }
}

class TransfersRepository {
  const TransfersRepository(this._dio);

  final Dio _dio;
  static const _uuid = Uuid();

  Future<List<StockTransferItem>> listTransfers({
    required String direction,
    String? status,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/transfers',
        queryParameters: {
          'direction': direction,
          if (status != null && status.isNotEmpty) 'status': status,
          'limit': 50,
        },
      );
      final list = res.data!['data'] as List<dynamic>;
      return list.map((e) => StockTransferItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> receive(int transferId, {String? receiverNote}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/transfers/$transferId/receive',
        data: {if (receiverNote != null && receiverNote.trim().isNotEmpty) 'receiverNote': receiverNote.trim()},
        options: Options(headers: {'X-Idempotency-Key': _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> reject(int transferId, {required String receiverNote}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/transfers/$transferId/reject',
        data: {'receiverNote': receiverNote.trim()},
        options: Options(headers: {'X-Idempotency-Key': _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> cancel(int transferId, {String? senderNote}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/transfers/$transferId/cancel',
        data: {if (senderNote != null && senderNote.trim().isNotEmpty) 'senderNote': senderNote.trim()},
        options: Options(headers: {'X-Idempotency-Key': _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final transfersRepositoryProvider = Provider<TransfersRepository>((ref) {
  return TransfersRepository(ref.watch(dioProvider));
});

final transferDirectionProvider = StateProvider<String>((ref) => 'incoming');
final transferStatusFilterProvider = StateProvider<String?>((ref) => 'IN_TRANSIT');

final transfersListProvider = FutureProvider<List<StockTransferItem>>((ref) {
  final direction = ref.watch(transferDirectionProvider);
  final status = ref.watch(transferStatusFilterProvider);
  return ref.watch(transfersRepositoryProvider).listTransfers(direction: direction, status: status);
});
