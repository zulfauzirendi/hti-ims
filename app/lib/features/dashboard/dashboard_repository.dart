import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import '../../layouts/adaptive_shell.dart';

class LocationSummary {
  const LocationSummary({
    required this.locationId,
    required this.code,
    required this.name,
    required this.locationType,
    required this.good,
    required this.service,
    required this.broken,
    required this.inTransit,
    required this.total,
  });

  final int locationId;
  final String code;
  final String name;
  final String locationType;
  final int good;
  final int service;
  final int broken;
  final int inTransit;
  final int total;

  double get goodRatio => total > 0 ? good / total : 1.0;

  factory LocationSummary.fromJson(Map<String, dynamic> json) => LocationSummary(
        locationId: (json['locationId'] as num).toInt(),
        code: json['code'] as String,
        name: json['name'] as String,
        locationType: (json['locationType'] as String?) ?? 'WAREHOUSE',
        good: (json['good'] as num).toInt(),
        service: (json['service'] as num).toInt(),
        broken: (json['broken'] as num).toInt(),
        inTransit: (json['inTransit'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );
}

class CategorySummary {
  const CategorySummary({
    required this.categoryId,
    required this.code,
    required this.name,
    required this.totalItems,
    required this.totalUnits,
  });

  final int categoryId;
  final String code;
  final String name;
  final int totalItems;
  final int totalUnits;

  factory CategorySummary.fromJson(Map<String, dynamic> json) => CategorySummary(
        categoryId: (json['categoryId'] as num).toInt(),
        code: json['code'] as String,
        name: json['name'] as String,
        totalItems: (json['totalItems'] as num).toInt(),
        totalUnits: (json['totalUnits'] as num).toInt(),
      );
}

class DashboardSummary {
  const DashboardSummary({
    required this.itemsCount,
    required this.good,
    required this.service,
    required this.broken,
    required this.inTransit,
    required this.totalVolume,
    required this.byLocation,
    required this.byCategory,
    required this.pendingIncomingTransfers,
  });

  final int itemsCount;
  final int good;
  final int service;
  final int broken;
  final int inTransit;
  final int totalVolume;
  final List<LocationSummary> byLocation;
  final List<CategorySummary> byCategory;
  final int pendingIncomingTransfers;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final grand = json['grandTotal'] as Map<String, dynamic>;
    return DashboardSummary(
      itemsCount: (grand['itemsCount'] as num).toInt(),
      good: (grand['good'] as num).toInt(),
      service: (grand['service'] as num).toInt(),
      broken: (grand['broken'] as num).toInt(),
      inTransit: (grand['inTransit'] as num).toInt(),
      totalVolume: (grand['totalVolume'] as num).toInt(),
      byLocation: (json['byLocation'] as List<dynamic>)
          .map((e) => LocationSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      byCategory: (json['byCategory'] as List<dynamic>)
          .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingIncomingTransfers: (json['pendingIncomingTransfers'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardRepository {
  const DashboardRepository(this._dio);

  final Dio _dio;

  Future<DashboardSummary> fetchSummary() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/dashboard/summary');
      return DashboardSummary.fromJson(res.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final summary = await ref.watch(dashboardRepositoryProvider).fetchSummary();
  Future.microtask(() {
    ref.read(pendingIncomingTransfersCountProvider.notifier).state = summary.pendingIncomingTransfers;
  });
  return summary;
});
