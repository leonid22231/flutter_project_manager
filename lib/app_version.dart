/// Keep this equal to the `version:` line in pubspec.yaml.
const String appVersion = '1.0.0+1';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');
  static final zipPattern = RegExp(
    r'^version_(\d+\.\d+\.\d+(?:\+\d+)?)\.zip$',
    caseSensitive: false,
  );

  static AppVersion? parse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4) ?? '0'),
    );
  }

  static String zipName(String version) => 'version_$version.zip';

  @override
  int compareTo(AppVersion other) {
    final parts = [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
      build.compareTo(other.build),
    ];
    for (final diff in parts) {
      if (diff != 0) return diff;
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() =>
      build == 0 ? '$major.$minor.$patch' : '$major.$minor.$patch+$build';
}
