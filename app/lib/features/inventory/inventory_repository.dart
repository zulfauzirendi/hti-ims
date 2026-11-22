import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/inventory_models.dart';
import '../../core/models/user_model.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class PagedInventoryResult {
  const PagedInventoryResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<InventoryItem> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

class InventoryRepository {
  const InventoryRepository(this._dio);

  final Dio _dio;
  static const _uuid = Uuid();

  Future<List<CategoryRef>> fetchCategories() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/categories');
      final list = res.data!['data'] as List<dynamic>;
      return list.map((e) => CategoryRef.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<LocationRef>> fetchLocations() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/locations');
      final list = res.data!['data'] as List<dynamic>;
      return list.map((e) => LocationRef.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PagedInventoryResult> searchItems({
    String? q,
    int? categoryId,
    int? locationId,
    String? condition,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/items/search',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'categoryId': ?categoryId,
          'locationId': ?locationId,
          if (condition != null && condition.isNotEmpty) 'condition': condition,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      final list = (res.data!['data'] as List<dynamic>)
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = (res.data!['meta'] as Map<String, dynamic>?) ?? {};
      return PagedInventoryResult(
        items: list,
        page: (meta['page'] as num?)?.toInt() ?? page,
        limit: (meta['limit'] as num?)?.toInt() ?? limit,
        total: (meta['total'] as num?)?.toInt() ?? list.length,
        totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw ApiException.fromDio(e);
    }
  }

  Future<String> uploadEvidencePhoto({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/uploads/evidence',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = res.data!['data'] as Map<String, dynamic>;
      return data['photoUrl'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateCondition({
    required int itemId,
    required int locationId,
    required String fromStatus,
    required String toStatus,
    required int qty,
    required String note,
    required int expectedVersion,
    String? photoUrl,
    String? jobCode,
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/stocks/update-condition',
        data: {
          'itemId': itemId,
          'locationId': locationId,
          'fromStatus': fromStatus,
          'toStatus': toStatus,
          'qty': qty,
          'note': note.trim(),
          'expectedVersion': expectedVersion,
          'photoUrl': ?photoUrl,
          if (jobCode != null && jobCode.trim().isNotEmpty) 'jobCode': jobCode.trim(),
        },
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey ?? _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateRemarks({
    required int itemId,
    required int locationId,
    required int expectedVersion,
    String? jobCode,
    String? remarks,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/api/v1/stocks/remarks',
        data: {
          'itemId': itemId,
          'locationId': locationId,
          'expectedVersion': expectedVersion,
          'jobCode': (jobCode != null && jobCode.trim().isNotEmpty) ? jobCode.trim() : null,
          'remarks': (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : null,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> stockIn({
    required int itemId,
    required int locationId,
    required int qty,
    required String note,
    int? expectedVersion,
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/stocks/in',
        data: {
          'itemId': itemId,
          'locationId': locationId,
          'qty': qty,
          'note': note.trim(),
          'expectedVersion': ?expectedVersion,
        },
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey ?? _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> disposeBroken({
    required int itemId,
    required int locationId,
    required int qty,
    required String note,
    required int expectedVersion,
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/stocks/dispose',
        data: {
          'itemId': itemId,
          'locationId': locationId,
          'qty': qty,
          'note': note.trim(),
          'expectedVersion': expectedVersion,
        },
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey ?? _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> createTransfer({
    required int itemId,
    required int fromLocationId,
    required int toLocationId,
    required String conditionStatus,
    required int qty,
    required String senderNote,
    required int expectedVersion,
    String? jobCode,
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/transfers',
        data: {
          'itemId': itemId,
          'fromLocationId': fromLocationId,
          'toLocationId': toLocationId,
          'conditionStatus': conditionStatus,
          'qty': qty,
          'senderNote': senderNote.trim(),
          'expectedVersion': expectedVersion,
          if (jobCode != null && jobCode.trim().isNotEmpty) 'jobCode': jobCode.trim(),
        },
        options: Options(headers: {'X-Idempotency-Key': idempotencyKey ?? _uuid.v4()}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> createMasterItem({
    required int categoryId,
    required String description,
    String? specification,
    required String unit,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/items',
        data: {
          'categoryId': categoryId,
          'description': description.trim(),
          if (specification != null && specification.trim().isNotEmpty)
            'specification': specification.trim(),
          'unit': unit,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(dioProvider));
});
