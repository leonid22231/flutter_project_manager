/// Command lines for the Windows sign-in task.
///
/// The runner in `windows/runner/main.cpp` treats the same `--minimized`
/// argument as "create the window minimized". Tests cover this parser and
/// the schtasks arguments. They do not run schtasks.
class WindowsLogonTask {
  const WindowsLogonTask._();

  static const taskName = 'ProjectManager';
  static const minimizedArgument = '--minimized';

  static bool isMinimizedLaunch(List<String> args) =>
      args.contains(minimizedArgument);

  static List<String> createArguments(String exePath) {
    return [
      '/Create',
      '/F',
      '/TN',
      taskName,
      '/SC',
      'ONLOGON',
      '/DELAY',
      '0000:30',
      '/RL',
      'LIMITED',
      '/TR',
      '"${exePath.trim()}" $minimizedArgument',
    ];
  }

  static List<String> deleteArguments() {
    return [
      '/Delete',
      '/F',
      '/TN',
      taskName,
    ];
  }
}
