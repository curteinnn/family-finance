import 'package:flutter/widgets.dart';

import 'app/family_finance_app.dart';

export 'app/family_finance_app.dart' show FamilyFinanceApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyFinanceApp());
}
