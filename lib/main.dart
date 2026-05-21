import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/table_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/starting_cash_provider.dart';
import 'providers/draft_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/qr_order_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/customer_order_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'utils/url_strategy_helper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Explicitly configure Firestore for offline persistence with unlimited cache size
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

  // Enable clean path URLs for Flutter web
  configureUrlStrategy();
  runApp(const DapoerManahanApp());
}

class DapoerManahanApp extends StatelessWidget {
  const DapoerManahanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()..init()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()..init()),
        ChangeNotifierProvider(create: (_) => TableProvider()..init()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..init()),
        ChangeNotifierProvider(create: (_) => StartingCashProvider()..loadStartingCash(DateTime.now())),
        ChangeNotifierProvider(create: (_) => DraftProvider()..fetchDrafts()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => QrOrderProvider()..init()),
        ChangeNotifierProvider(create: (_) => ChatProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          // Sync AppColors with current theme
          final Brightness platformBrightness = PlatformDispatcher.instance.platformBrightness;
          final bool isSystemDark = platformBrightness == Brightness.dark;
          final bool isDark = themeProv.themeMode == ThemeMode.dark || 
                            (themeProv.themeMode == ThemeMode.system && isSystemDark);
          AppColors.setDarkMode(isDark);

          return MaterialApp(
            title: DefaultData.restaurantName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            onGenerateRoute: (settings) {
              final name = settings.name ?? '';
              // For hash‑based URLs on web (e.g., http://example.com/#/table/5)
              // Uri.base.path may be '/' and the actual route is stored in the fragment.
              final fragment = Uri.base.fragment;
              final effectiveName = (name.isEmpty && fragment.isNotEmpty) ? '/${fragment.replaceFirst(RegExp(r'^/'), '')}' : name;
              if (effectiveName.startsWith('/table/')) {
                final tableNumber = effectiveName.replaceFirst('/table/', '');
                return MaterialPageRoute(
                  builder: (_) => CustomerOrderScreen(tableNumber: tableNumber),
                  settings: settings,
                );
              }
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
                settings: settings,
              );
            },
          );
        },
      ),
    );
  }
}
