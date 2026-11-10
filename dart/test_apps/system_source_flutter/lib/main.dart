import 'package:flutter/material.dart';
import 'package:noda_dart/system.dart';
import 'package:noda_dart/tzdb_bundled.dart';

/// Hosts the integration tests; on its own, shows what the system provider reports.
void main() {
  runApp(SystemSourceApp(summary: describeSystemSource()));
}

String describeSystemSource() {
  try {
    final provider = SystemDateTimeZoneProvider;
    final zone = provider.GetSystemDefault();
    return '${provider.VersionId}\n'
        '${provider.Ids.length} zones\n'
        'System default: ${zone.Id}\n'
        'tzdb (${tzdb.VersionId}) system default: ${tzdb.GetSystemDefault().Id}';
  } catch (error) {
    return 'SystemDateTimeZoneSource failed: $error';
  }
}

class SystemSourceApp extends StatelessWidget {
  const SystemSourceApp({super.key, required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SystemDateTimeZoneSource',
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(summary),
            ),
          ),
        ),
      );
}
