# Mojibake fix (Training / Обучение)

## Cause
On Windows, `Process.run` defaults to `systemEncoding` for stdout. Cursor CLI returns UTF-8 → Dart decoded as CP1252 → `Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ð½Ð¾`. Same risk with `File.readAsString` / `writeAsString` without `encoding: utf8`.

## Fix
- `utf8` for all Cursor `Process.run` stdout/stderr
- `readUtf8File` / `writeUtf8File` for `.ai` JSON
- `repairUtf8Mojibake` on load of learning-pending (rewrites file if corrupted)
- Mermaid diagram area uses light background so PNG labels stay visible
