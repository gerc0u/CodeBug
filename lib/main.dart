import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/progress.dart';
import 'ui/design.dart';
import 'ui/home.dart';
import 'ui/auth.dart';
import 'data/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(DebugLabApp(store: ProgressStore(preferences, api: CodeBugApi())));
}

class DebugLabApp extends StatefulWidget {
  const DebugLabApp({super.key, required this.store, this.showSplash = true});
  final ProgressStore store;
  final bool showSplash;
  @override
  State<DebugLabApp> createState() => _DebugLabAppState();
}

class _DebugLabAppState extends State<DebugLabApp> {
  ProgressStore get store => widget.store;
  late bool ready = !widget.showSplash;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (!ready) {
      timer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => ready = true);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      key: ValueKey(store.api == null ? 'local' : store.userId ?? 'guest'),
      title: 'CodeBug — тренажёр разработчика',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
      home: !ready
          ? const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report_rounded, size: 88, color: violet),
                      SizedBox(height: 24),
                      Text(
                        'CodeBug',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Находи ошибки. Развивай навыки.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      SizedBox(width: 140, child: LinearProgressIndicator()),
                    ],
                  ),
                ),
              ),
            )
          : store.api != null && !store.authenticated
          ? AuthPage(store: store)
          : HomeShell(store: store),
    ),
  );
  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8D64E8),
          brightness: brightness,
        ).copyWith(
          primary: dark ? violet : const Color(0xFF6942BB),
          surface: dark ? const Color(0xFF191522) : const Color(0xFFF7F4FC),
          onSurface: dark ? const Color(0xFFF4F0FF) : const Color(0xFF241B34),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF211B2E) : Colors.white,
        indicatorColor: violet.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF211D30) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
      ),
      dividerColor: dark ? const Color(0xFF342D46) : const Color(0xFFE5DDF2),
    );
  }
}
