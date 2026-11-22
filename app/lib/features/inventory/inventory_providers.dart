import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_models.dart';
import '../../core/models/user_model.dart';
import 'inventory_repository.dart';

class InventoryFilter {
  const InventoryFilter({
    this.query = '',
    this.categoryId,
    this.locationId,
    this.condition,
    this.page = 1,
  });

  final String query;
  final int? categoryId;
  final int? locationId;
  final String? condition;
  final int page;

  InventoryFilter copyWith({
    String? query,
    int? Function()? categoryId,
    int? Function()? locationId,
    String? Function()? condition,
    int? page,
  }) {
    return InventoryFilter(
      query: query ?? this.query,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      locationId: locationId != null ? locationId() : this.locationId,
      condition: condition != null ? condition() : this.condition,
      page: page ?? this.page,
    );
  }
}

final categoriesProvider = FutureProvider<List<CategoryRef>>((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchCategories();
});

final locationsProvider = FutureProvider<List<LocationRef>>((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchLocations();
});

final inventoryFilterProvider = StateProvider<InventoryFilter>((ref) => const InventoryFilter());

final inventorySearchProvider = FutureProvider<PagedInventoryResult>((ref) async {
  final filter = ref.watch(inventoryFilterProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  return ref.watch(inventoryRepositoryProvider).searchItems(
        q: filter.query,
        categoryId: filter.categoryId,
        locationId: filter.locationId,
        condition: filter.condition,
        page: filter.page,
        limit: 20,
        cancelToken: cancelToken,
      );
});
