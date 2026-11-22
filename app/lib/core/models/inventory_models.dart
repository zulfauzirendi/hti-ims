class CategoryRef {
  const CategoryRef({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory CategoryRef.fromJson(Map<String, dynamic> json) => CategoryRef(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String,
        name: json['name'] as String,
      );
}

class ItemStockEntry {
  const ItemStockEntry({
    this.stockId,
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.locationType,
    required this.qtyGood,
    required this.qtyService,
    required this.qtyBroken,
    required this.qtyInTransit,
    this.jobCode,
    this.remarks,
    required this.version,
    this.updatedAt,
  });

  final int? stockId;
  final int locationId;
  final String locationCode;
  final String locationName;
  final String locationType;
  final int qtyGood;
  final int qtyService;
  final int qtyBroken;
  final int qtyInTransit;
  final String? jobCode;
  final String? remarks;
  final int version;
  final DateTime? updatedAt;

  int get total => qtyGood + qtyService + qtyBroken + qtyInTransit;

  factory ItemStockEntry.fromJson(Map<String, dynamic> json) => ItemStockEntry(
        stockId: (json['stockId'] as num?)?.toInt(),
        locationId: (json['locationId'] as num).toInt(),
        locationCode: json['locationCode'] as String,
        locationName: json['locationName'] as String,
        locationType: (json['locationType'] as String?) ?? 'WAREHOUSE',
        qtyGood: (json['qtyGood'] as num).toInt(),
        qtyService: (json['qtyService'] as num).toInt(),
        qtyBroken: (json['qtyBroken'] as num).toInt(),
        qtyInTransit: (json['qtyInTransit'] as num).toInt(),
        jobCode: json['jobCode'] as String?,
        remarks: json['remarks'] as String?,
        version: (json['version'] as num?)?.toInt() ?? 1,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.itemCode,
    required this.description,
    this.specification,
    required this.unit,
    required this.category,
    required this.stocks,
  });

  final int id;
  final String itemCode;
  final String description;
  final String? specification;
  final String unit;
  final CategoryRef category;
  final List<ItemStockEntry> stocks;

  int get totalGood => stocks.fold(0, (s, e) => s + e.qtyGood);
  int get totalService => stocks.fold(0, (s, e) => s + e.qtyService);
  int get totalBroken => stocks.fold(0, (s, e) => s + e.qtyBroken);
  int get totalInTransit => stocks.fold(0, (s, e) => s + e.qtyInTransit);
  int get totalVolume => totalGood + totalService + totalBroken + totalInTransit;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: (json['id'] as num).toInt(),
        itemCode: json['itemCode'] as String,
        description: json['description'] as String,
        specification: json['specification'] as String?,
        unit: json['unit'] as String,
        category: CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
        stocks: (json['stocks'] as List<dynamic>? ?? const [])
            .map((e) => ItemStockEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HealthCheckResult {
  const HealthCheckResult({
    required this.ok,
    required this.latencyMs,
    required this.message,
    this.latestClientVersion,
  });

  final bool ok;
  final int latencyMs;
  final String message;
  final String? latestClientVersion;
}
