# Builds tab rework — 2026-07-11

## UI
- Summary header with build-stage badge, defaults/tasks.json hints
- Config list grouped by platform (Android, iOS, Windows, Web, Linux, macOS, GitLab CI, Other)
- Platform-colored icons on config tiles
- Removed old filter chips (All/Tasks/Defaults/GitLab CI)

## Filtering
- `tasks.json`: only tasks with `group: build`
- `.gitlab-ci.yml`: only jobs with `stage: build` (excludes `pre_build`, `analyze_and_test`)
- Fixed parser bug: anchor blocks (`.android_config`) no longer leak into previous job

## Files
- `lib/ui/views/builds_view.dart`
- `lib/services/gitlab_ci_config_parser.dart`
- `lib/services/vscode_build_config_service.dart`
- `lib/services/gitlab_ci_build_service.dart`
- `lib/l10n/app_localizations.dart` — `buildsStageBuildOnly`
- `test/gitlab_ci_config_parser_test.dart`
