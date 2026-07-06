import 'package:flutter/material.dart';

import 'package:project_manager/core/theme/idea_theme.dart';

import 'package:project_manager/l10n/app_localizations.dart';



class EmptyStateView extends StatelessWidget {

  const EmptyStateView({super.key});



  @override

  Widget build(BuildContext context) {

    final l10n = context.l10n;

    return Center(

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(

            Icons.dashboard_outlined,

            size: 64,

            color: IdeaColors.textSecondary.withValues(alpha: 0.5),

          ),

          const SizedBox(height: 16),

          Text(

            l10n.welcomeTitle,

            style: Theme.of(context).textTheme.titleLarge,

          ),

          const SizedBox(height: 8),

          SizedBox(

            width: 400,

            child: Text(

              l10n.welcomeHint,

              style: Theme.of(context).textTheme.bodySmall,

              textAlign: TextAlign.center,

            ),

          ),

        ],

      ),

    );

  }

}

