import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/shell/ide_shell.dart';
import 'package:provider/provider.dart';

class ProjectManagerApp extends StatelessWidget {
  const ProjectManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppSettingsState()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProjectManagerState()..initialize(),
        ),
      ],
      child: Consumer<AppSettingsState>(
        builder: (context, settings, _) {
          if (settings.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: IdeaTheme.dark,
              home: const Scaffold(
                backgroundColor: Color(0xFF2B2B2B),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4A9FF5)),
                ),
              ),
            );
          }

          return MaterialApp(
            title: 'Project Manager',
            debugShowCheckedModeBanner: false,
            theme: IdeaTheme.dark,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const IdeShell(),
          );
        },
      ),
    );
  }
}
