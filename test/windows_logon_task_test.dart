import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/models/windows_launch_settings.dart';
import 'package:project_manager/services/windows_logon_task.dart';

void main() {
  test('--minimized is recognized only as its own argument', () {
    expect(WindowsLogonTask.isMinimizedLaunch(const []), isFalse);
    expect(
      WindowsLogonTask.isMinimizedLaunch(const ['--minimized']),
      isTrue,
    );
    expect(
      WindowsLogonTask.isMinimizedLaunch(
        const ['--other', '--minimized', 'extra'],
      ),
      isTrue,
    );
    expect(
      WindowsLogonTask.isMinimizedLaunch(const ['--minimized=true']),
      isFalse,
    );
  });

  test('create command is the logon task with a minimized exe', () {
    const exe = r'C:\Tools\Project Manager\project_manager.exe';
    expect(
      WindowsLogonTask.createArguments(exe),
      [
        '/Create',
        '/F',
        '/TN',
        'ProjectManager',
        '/SC',
        'ONLOGON',
        '/DELAY',
        '0000:30',
        '/RL',
        'LIMITED',
        '/TR',
        '"$exe" --minimized',
      ],
    );
  });

  test('delete command removes the ProjectManager task', () {
    expect(
      WindowsLogonTask.deleteArguments(),
      ['/Delete', '/F', '/TN', 'ProjectManager'],
    );
  });

  test('empty exe path falls back to the current process exe', () {
    const settings = WindowsLaunchSettings(launchAtLogon: true);
    final resolved = settings.withDefaultExe(r'D:\app\project_manager.exe');
    expect(resolved.exePath, r'D:\app\project_manager.exe');
    expect(resolved.launchAtLogon, isTrue);

    final kept = const WindowsLaunchSettings(exePath: r'C:\kept.exe')
        .withDefaultExe(r'D:\app\project_manager.exe');
    expect(kept.exePath, r'C:\kept.exe');
  });
}
