import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HtiInventoryApp()));
}

class HtiInventoryApp extends ConsumerWidget {
  const HtiInventoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PT HTI Tool & Equipment Inventory',
      debugShowCheckedModeBanner: false,
      theme: HtiTheme.light(),
      routerConfig: router,
    );
  }
}
