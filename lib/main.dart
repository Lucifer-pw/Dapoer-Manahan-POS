import 'package:flutter/material.dart';
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
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp(
            title: DefaultData.restaurantName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
