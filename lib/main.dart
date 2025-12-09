import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'package:course/providers/theme_provider.dart';
import 'package:course/services/auth_service.dart';
import 'package:course/screens/auth_gate.dart';

// Локализация
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:course/generated/app_localizations.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ВАЖНО: на Web обязательно через options: DefaultFirebaseOptions.currentPlatform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Локализация
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      themeMode: themeProvider.themeMode,
      theme: themeProvider.currentLightTheme,
      darkTheme: themeProvider.currentDarkTheme,

      home: const AuthGate(),
    );
  }
}
