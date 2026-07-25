import 'package:auto_sms/app/app.dart';
import 'package:auto_sms/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
