import 'package:flutter_test/flutter_test.dart';
import 'package:guruproxy/main.dart';
import 'package:guruproxy/app_state.dart';
import 'package:guruproxy/services/asset_bootstrap.dart';
import 'package:guruproxy/services/settings_store.dart';
import 'package:guruproxy/services/tunnel_engine.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GuruProxy shell loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    final bootstrap = AssetBootstrap();
    final tunnel = TunnelEngine(settings: settings, bootstrap: bootstrap);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState(settings: settings, tunnel: tunnel)),
        ],
        child: const GuruProxyApp(),
      ),
    );
    await tester.pump();
    expect(find.text('GuruProxy'), findsWidgets);
  });
}
