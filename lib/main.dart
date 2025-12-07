import 'package:course/generated/app_localizations.dart';
import 'package:course/providers/theme_provider.dart';
import 'package:course/screens/auth_gate.dart';
import 'package:course/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// ЛОКАЛИЗАЦИЯ
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const CourseAppRoot(),
    ),
  );
}

class CourseAppRoot extends StatelessWidget {
  const CourseAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      /// Заголовок приложения из локализации (ключ appTitle в app_*.arb)
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

      /// Делегаты локализации — БЕЗ них AppLocalizations.of(context) будет null
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      /// Список поддерживаемых языков
      supportedLocales: AppLocalizations.supportedLocales,
      // Если хочешь зафиксировать язык:
      // locale: const Locale('ru'),

      themeMode: themeProvider.themeMode,
      theme: themeProvider.currentLightTheme,
      darkTheme: themeProvider.currentDarkTheme,

      home: const AuthGate(),
    );
  }
}
