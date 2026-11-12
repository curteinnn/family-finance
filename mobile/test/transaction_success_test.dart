import 'package:family_finance/api/api_client.dart';
import 'package:family_finance/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    this.failTransaction = false,
    this.unknownTransaction = false,
  });

  final bool failTransaction;
  final bool unknownTransaction;
  final List<Map<String, dynamic>> transferRows = [];
  final List<Map<String, dynamic>> expenseRows = [];
  final Map<String, int> listCalls = {};
  final List<String> submittedPaths = [];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/families/me') {
      return {
        'name': 'Family',
        'children': [
          {
            'userId': 'child-id',
            'name': 'Alya',
            'wallet': {
              'id': 'wallet-id',
              'name': 'Wallet Alya',
              'isActive': true,
            },
          },
          {
            'userId': 'child-2-id',
            'name': 'Bima',
            'wallet': {
              'id': 'wallet-2-id',
              'name': 'Wallet Bima',
              'isActive': true,
            },
          },
        ],
      };
    }
    if (path == '/reports/overview') {
      return {
        'totals': {
          'confirmedIncome': '0',
          'activeExpenses': '0',
          'balance': '0',
        },
        'children': [
          {
            'childId': 'child-id',
            'name': 'Alya',
            'walletActive': true,
            'balance': '15000',
          },
          {
            'childId': 'child-2-id',
            'name': 'Bima',
            'walletActive': true,
            'balance': '7500',
          },
        ],
      };
    }
    if (path.startsWith('/reports/monthly')) {
      return {
        'year': 2026,
        'month': 11,
        'totals': {
          'confirmedIncome': '25000',
          'activeExpenses': '5000',
          'net': '20000',
          'transferCount': 1,
          'expenseCount': 1,
        },
        'expensesByCategory': [
          {'categoryName': 'Makanan', 'amount': '5000', 'count': 1},
          {'categoryName': 'Transportasi', 'amount': '1000', 'count': 1},
          {'categoryName': 'Pendidikan', 'amount': '2000', 'count': 1},
          {'categoryName': 'Hiburan', 'amount': '3000', 'count': 1},
          {'categoryName': 'Kesehatan', 'amount': '4000', 'count': 1},
          {'categoryName': 'Lainnya', 'amount': '5000', 'count': 1},
        ],
      };
    }
    if (path.startsWith('/history')) return {'items': <dynamic>[]};
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    listCalls.update(path, (count) => count + 1, ifAbsent: () => 1);
    return switch (path) {
      '/transfers' => transferRows,
      '/expenses' => expenseRows,
      '/categories' => [
        {'id': 'food-id', 'name': 'Makanan'},
      ],
      '/notifications' => <dynamic>[],
      _ => throw StateError('Unexpected list GET $path'),
    };
  }

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    submittedPaths.add(path);
    if (failTransaction) {
      throw const ApiException('Saldo tidak mencukupi.', statusCode: 400);
    }
    if (unknownTransaction) {
      throw const ApiException('Koneksi terputus.');
    }
    if (path == '/transfers') {
      transferRows.add({
        'id': 'transfer-id',
        'amount': body!['amount'],
        'note': body['note'],
        'status': 'PENDING',
        'child': {'name': 'Alya'},
        'parent': {'name': 'Parent'},
        'wallet': {'id': 'wallet-id', 'name': 'Wallet'},
      });
    } else if (path == '/expenses') {
      expenseRows.add({
        'id': 'expense-id',
        'amount': body!['amount'],
        'description': body['description'],
        'status': 'ACTIVE',
        'category': {'id': 'food-id', 'name': 'Makanan'},
        'child': {'name': 'Alya'},
      });
    } else {
      throw StateError('Unexpected POST $path');
    }
    return {'id': 'created-id'};
  }
}

Future<void> _openHome(
  WidgetTester tester,
  _FakeApiClient api, {
  required String role,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        api: api,
        user: {
          'id': role == 'PARENT' ? 'parent-id' : 'child-id',
          'name': role == 'PARENT' ? 'Parent' : 'Alya',
          'role': role,
        },
        onSignOut: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownOption(WidgetTester tester, String option) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('parent transfer succeeds, refreshes data, and shows details', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await _openHome(tester, api, role: 'PARENT');

    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();
    await _selectDropdownOption(tester, 'Alya');
    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(api.submittedPaths, ['/transfers']);
    expect(api.listCalls['/transfers'], 2);
    expect(find.textContaining('Transfer berhasil'), findsOneWidget);
    expect(find.textContaining('Rp 25.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('child expense succeeds, refreshes data, and shows details', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await _openHome(tester, api, role: 'CHILD');

    await tester.tap(find.text('Pengeluaran').first);
    await tester.pumpAndSettle();
    await _selectDropdownOption(tester, 'Makanan');
    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.enterText(find.byType(TextField).last, 'Makan siang');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(api.submittedPaths, ['/expenses']);
    expect(api.listCalls['/expenses'], 2);
    expect(find.textContaining('Pengeluaran berhasil dicatat'), findsOneWidget);
    expect(find.textContaining('Rp 12.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('failed expense does not show success feedback', (tester) async {
    final api = _FakeApiClient(failTransaction: true);
    await _openHome(tester, api, role: 'CHILD');

    await tester.tap(find.text('Pengeluaran').first);
    await tester.pumpAndSettle();
    await _selectDropdownOption(tester, 'Makanan');
    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(api.submittedPaths, ['/expenses']);
    expect(find.text('Saldo tidak mencukupi.'), findsOneWidget);
    expect(find.textContaining('Pengeluaran berhasil dicatat'), findsNothing);
    expect(find.text('Catat pengeluaran'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('uncertain response is not retried and shows no success', (
    tester,
  ) async {
    final api = _FakeApiClient(unknownTransaction: true);
    await _openHome(tester, api, role: 'PARENT');

    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();
    await _selectDropdownOption(tester, 'Alya');
    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(api.submittedPaths, ['/transfers']);
    expect(
      find.textContaining('Status transfer belum dapat dipastikan'),
      findsOneWidget,
    );
    expect(find.textContaining('Transfer berhasil'), findsNothing);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('parent wallet summary opens child balances without refetching', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await _openHome(tester, api, role: 'PARENT');

    expect(find.text('Total Wallet Anak'), findsOneWidget);
    expect(find.text('2 anak memiliki wallet'), findsOneWidget);
    expect(find.text('Rp 22.500'), findsOneWidget);
    expect(api.listCalls['/transfers'], 1);

    await tester.ensureVisible(find.text('Total Wallet Anak'));
    await tester.tap(find.text('Total Wallet Anak'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet Anak'), findsOneWidget);
    expect(find.text('Alya'), findsOneWidget);
    expect(find.text('Bima'), findsOneWidget);
    expect(find.text('Rp 15.000'), findsOneWidget);
    expect(find.text('Rp 7.500'), findsOneWidget);
    expect(api.listCalls['/transfers'], 1);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('monthly report card opens full report details', (tester) async {
    final api = _FakeApiClient();
    await _openHome(tester, api, role: 'PARENT');

    await tester.ensureVisible(find.text('Laporan Bulan Ini'));
    await tester.tap(find.text('Laporan Bulan Ini'));
    await tester.pumpAndSettle();

    expect(find.text('Pemasukan terkonfirmasi'), findsOneWidget);
    expect(find.text('Pengeluaran per kategori'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

  testWidgets('finance flow tabs show transfer and expense entries', (
    tester,
  ) async {
    final api = _FakeApiClient();
    api.transferRows.add({
      'id': 'transfer-existing',
      'amount': '5000',
      'note': 'Uang saku',
      'status': 'PENDING',
      'createdAt': '2026-11-10T00:00:00.000Z',
      'child': {'name': 'Alya'},
      'parent': {'name': 'Parent'},
    });
    api.expenseRows.add({
      'id': 'expense-existing',
      'amount': '2000',
      'description': 'Roti',
      'status': 'ACTIVE',
      'spentAt': '2026-11-09T00:00:00.000Z',
      'category': {'id': 'food-id', 'name': 'Makanan'},
      'child': {'name': 'Alya'},
    });
    await _openHome(tester, api, role: 'PARENT');

    expect(find.text('Uang saku'), findsOneWidget);
    expect(find.text('Untuk Alya · 10/11/2026'), findsOneWidget);
    await tester.tap(find.text('Pengeluaran Terbaru'));
    await tester.pumpAndSettle();

    expect(find.text('Roti'), findsOneWidget);
    expect(find.text('Makanan · Alya · 09/11/2026'), findsOneWidget);
    expect(find.text('Uang saku'), findsNothing);
    expect(tester.takeException(), isNull);
    api.dispose();
  });
}
