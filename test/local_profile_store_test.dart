import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qx_studio/services/local_profile_store.dart';

void main() {
  late Directory directory;
  late LocalProfileStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qx_profile_test_');
    store = LocalProfileStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('returns an empty local profile when no profile is saved', () async {
    final profile = await store.load();

    expect(profile.displayName, isEmpty);
    expect(profile.themeMode, 'dark');
  });

  test('loads older profiles with the dark theme default', () async {
    await File('${directory.path}/qx_local_profile.json').writeAsString(
      jsonEncode({'displayName': 'Existing User'}),
    );
    final loaded = await store.load();
    expect(loaded.displayName, 'Existing User');
    expect(loaded.themeMode, 'dark');
  });

  test('saves theme mode without discarding existing profile fields', () async {
    await File('${directory.path}/qx_local_profile.json').writeAsString(
      jsonEncode({'displayName': 'Old Name', 'customField': 'keep-me'}),
    );
    await store.save(
      const LocalProfile(displayName: '  QX User  ', themeMode: 'light'),
    );
    final loaded = await store.load();
    final savedJson = jsonDecode(
      await File('${directory.path}/qx_local_profile.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(loaded.displayName, 'QX User');
    expect(loaded.themeMode, 'light');
    expect(savedJson['customField'], 'keep-me');
  });

  test('saves and reloads the display name locally', () async {
    await store.save(const LocalProfile(displayName: '  QX User  '));

    final loaded = await store.load();

    expect(loaded.displayName, 'QX User');
    expect(await File('${directory.path}/qx_local_profile.json').exists(), isTrue);
  });
}
