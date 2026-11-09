import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalProfile {
  const LocalProfile({this.displayName = ''});

  final String displayName;
}

class LocalProfileStore {
  LocalProfileStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;
  static const _fileName = 'qx_local_profile.json';

  Future<LocalProfile> load() async {
    final file = await _profileFile();
    if (!await file.exists()) return const LocalProfile();
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid local profile format.');
    }
    return LocalProfile(displayName: (decoded['displayName'] as String?) ?? '');
  }

  Future<LocalProfile> save(LocalProfile profile) async {
    final file = await _profileFile();
    final saved = LocalProfile(displayName: profile.displayName.trim());
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'displayName': saved.displayName,
      }),
      flush: true,
    );
    return saved;
  }

  Future<File> _profileFile() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }
}
