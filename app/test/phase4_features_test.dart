import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hti_inventory_app/core/models/inventory_models.dart';
import 'package:hti_inventory_app/core/models/user_model.dart';
import 'package:hti_inventory_app/core/theme/app_theme.dart';
import 'package:hti_inventory_app/features/auth/auth_controller.dart';
import 'package:hti_inventory_app/features/dashboard/dashboard_repository.dart';
import 'package:hti_inventory_app/features/dashboard/dashboard_screen.dart';
import 'package:hti_inventory_app/features/inventory/stock_action_modals.dart';
import 'package:hti_inventory_app/features/transfers/transfers_repository.dart';
import 'package:hti_inventory_app/features/transfers/transfers_screen.dart';

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final UserProfile _user;

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _user);
}

void main() {
  const sampleItem = InventoryItem(
    id: 1,
    itemCode: 'HTI-EQP-0001',
    description: 'Crane 50T',
    specification: 'TADANO',
    unit: 'UNIT',
    category: CategoryRef(id: 1, code: 'EQP', name: 'EQUIPMENT'),
    stocks: [],
  );

  const sampleStock = ItemStockEntry(
    stockId: 10,
    locationId: 1,
    locationCode: 'WH-1',
    locationName: 'Warehouse 1',
    locationType: 'WAREHOUSE',
    qtyGood: 5,
    qtyService: 1,
    qtyBroken: 2,
    qtyInTransit: 0,
    version: 1,
  );

  const sampleLocations = [
    LocationRef(id: 1, code: 'WH-1', name: 'Warehouse 1', locationType: 'WAREHOUSE'),
    LocationRef(id: 2, code: 'WH-2', name: 'Warehouse 2', locationType: 'WAREHOUSE'),
    LocationRef(id: 3, code: 'SITE-PTS', name: 'Site PTS', locationType: 'SITE'),
    LocationRef(id: 4, code: 'SITE-NON-PTS', name: 'Site Non PTS', locationType: 'SITE'),
  ];

  testWidgets('ConditionUpdateDialog blocks submit to SERVICE/BROKEN without ISO 45001 photo',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HtiTheme.light(),
          home: const Scaffold(
            body: ConditionUpdateDialog(item: sampleItem, stock: sampleStock),
          ),
        ),
      ),
    );

    // Isi catatan valid tapi tanpa unggah foto bukti K3
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Catatan Kondisi / Kerusakan (Wajib)'),
      'Kabel hoist terkelupas saat inspeksi',
    );
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wajib melampirkan bukti foto fisik (ISO 45001)'), findsOneWidget);
  });

  testWidgets('CreateTransferDialog displays K3 unsafe warning when BROKEN is selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HtiTheme.light(),
          home: const Scaffold(
            body: CreateTransferDialog(
              item: sampleItem,
              sourceStock: sampleStock,
              allLocations: sampleLocations,
            ),
          ),
        ),
      ),
    );

    // Awalnya GOOD -> tidak ada banner peringatan K3
    expect(find.textContaining('TIDAK LAYAK OPERASI'), findsNothing);

    // Ubah kondisi ke BROKEN
    await tester.tap(find.text('GOOD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BROKEN').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('PERINGATAN K3'), findsOneWidget);
    expect(find.textContaining('TIDAK LAYAK OPERASI'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders 4 PT HTI locations and baseline grand totals',
      (tester) async {
    const fakeSummary = DashboardSummary(
      itemsCount: 531,
      good: 10340,
      service: 119,
      broken: 2349,
      inTransit: 0,
      totalVolume: 12808,
      pendingIncomingTransfers: 2,
      byLocation: [
        LocationSummary(
          locationId: 1,
          code: 'WH-1',
          name: 'Warehouse 1',
          locationType: 'WAREHOUSE',
          good: 8096,
          service: 111,
          broken: 2242,
          inTransit: 0,
          total: 10449,
        ),
        LocationSummary(
          locationId: 2,
          code: 'WH-2',
          name: 'Warehouse 2',
          locationType: 'WAREHOUSE',
          good: 1830,
          service: 8,
          broken: 107,
          inTransit: 0,
          total: 1945,
        ),
        LocationSummary(
          locationId: 3,
          code: 'SITE-PTS',
          name: 'Site PTS',
          locationType: 'SITE',
          good: 200,
          service: 0,
          broken: 0,
          inTransit: 0,
          total: 200,
        ),
        LocationSummary(
          locationId: 4,
          code: 'SITE-NON-PTS',
          name: 'Site Non PTS',
          locationType: 'SITE',
          good: 214,
          service: 0,
          broken: 0,
          inTransit: 0,
          total: 214,
        ),
      ],
      byCategory: [
        CategorySummary(categoryId: 1, code: 'EQP', name: 'EQUIPMENT', totalItems: 42, totalUnits: 310),
      ],
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryProvider.overrideWith((ref) async => fakeSummary),
        ],
        child: MaterialApp(
          theme: HtiTheme.light(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warehouse 1'), findsOneWidget);
    expect(find.text('Warehouse 2'), findsOneWidget);
    expect(find.text('Site PTS'), findsOneWidget);
    expect(find.text('Site Non PTS'), findsOneWidget);
    expect(find.text('2 Transfer Masuk Menunggu Konfirmasi'), findsOneWidget);
  });

  testWidgets('TransfersScreen shows Receive & Reject buttons for authorized Site PTS technician',
      (tester) async {
    const sitePtsUser = UserProfile(
      id: 4,
      username: 'site_pts',
      fullName: 'Teknisi Site PTS',
      role: UserRole.petugasLapangan,
      mustChangePassword: false,
      assignedLocation: LocationRef(id: 3, code: 'SITE-PTS', name: 'Site PTS', locationType: 'SITE'),
    );

    final incoming = [
      StockTransferItem(
        id: 77,
        transferCode: 'TRF-20261122-AB12CD',
        itemCode: 'HTI-EQP-0001',
        itemDescription: 'Crane 50T',
        itemUnit: 'UNIT',
        fromLocationId: 1,
        fromLocationCode: 'WH-1',
        fromLocationName: 'Warehouse 1',
        toLocationId: 3,
        toLocationCode: 'SITE-PTS',
        toLocationName: 'Site PTS',
        conditionStatus: 'GOOD',
        qty: 1,
        status: 'IN_TRANSIT',
        sentByName: 'Admin WH1',
        senderNote: 'Untuk proyek 1P-31-180',
        jobCode: '1P-31-180',
        sentAt: DateTime(2026, 11, 22, 10, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _StubAuthController(sitePtsUser)),
          transfersListProvider.overrideWith((ref) async => incoming),
        ],
        child: MaterialApp(
          theme: HtiTheme.light(),
          home: const Scaffold(body: TransfersScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRF-20261122-AB12CD'), findsOneWidget);
    expect(find.text('Konfirmasi Terima'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    // Teknisi SITE-PTS bukan pengirim (WH-1) -> tidak boleh melihat tombol Batalkan Pengiriman
    expect(find.text('Batalkan Pengiriman'), findsNothing);
  });
}
