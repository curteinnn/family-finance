import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onSignOut,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  bool _working = false;
  String? _error;
  Map<String, dynamic> _family = {};
  Map<String, dynamic> _report = {};
  Map<String, dynamic> _monthlyReport = {};
  List<Map<String, dynamic>> _families = [];
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _history = [];

  String get _role => widget.user['role']?.toString() ?? '';
  bool get _isParent => _role == 'PARENT';
  bool get _isChild => _role == 'CHILD';
  bool get _isAdmin => _role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isAdmin) {
        _families = _maps(await widget.api.getList('/families'));
        _notifications = _maps(await widget.api.getList('/notifications'));
      } else {
        final now = DateTime.now().toUtc();
        final data = await Future.wait<dynamic>([
          widget.api.get('/families/me'),
          widget.api.get('/reports/overview'),
          widget.api.get(
            '/reports/monthly?year=${now.year}&month=${now.month}',
          ),
          widget.api.get('/history?page=1&limit=50'),
          widget.api.getList('/transfers'),
          widget.api.getList('/expenses'),
          widget.api.getList('/categories'),
          widget.api.getList('/notifications'),
        ]);
        _family = _map(data[0]);
        _report = _map(data[1]);
        _monthlyReport = _map(data[2]);
        _history = _maps(_map(data[3])['items']);
        _transfers = _maps(data[4]);
        _expenses = _maps(data[5]);
        _categories = _maps(data[6]);
        _notifications = _maps(data[7]);
      }
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Tidak bisa memuat data. Periksa koneksi ke backend.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (!mounted) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted && successMessage != null) _message(successMessage);
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Aksi gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _confirmTransfer(String id) => _perform(
    () async => widget.api.patch('/transfers/$id/confirm'),
    successMessage: 'Penerimaan transfer dikonfirmasi.',
  );

  Future<void> _rejectTransfer(String id) async {
    final reason = await _textDialog(
      title: 'Tolak transfer',
      label: 'Alasan (opsional)',
    );
    if (reason == null) return;
    await _perform(
      () async => widget.api.patch(
        '/transfers/$id/reject',
        reason.trim().isEmpty ? null : {'reason': reason.trim()},
      ),
      successMessage: 'Transfer ditolak. Saldo tidak berubah.',
    );
  }

  Future<void> _cancelTransfer(String id) => _perform(
    () async => widget.api.patch('/transfers/$id/cancel'),
    successMessage: 'Transfer dibatalkan.',
  );

  Future<String?> _textDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createTransfer() async {
    if (_family['children'] is! List || (_family['children'] as List).isEmpty) {
      _message('Family ini belum memiliki child.');
      return;
    }
    final children = _maps(_family['children']);
    final result = await showDialog<_TransactionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferDialog(
        children: children,
        onSubmit: (data) async {
          await widget.api.post('/transfers', {
            'childId': data['childId'],
            'amount': data['amount'],
            if (data['note']!.trim().isNotEmpty) 'note': data['note']!.trim(),
          });
        },
      ),
    );
    if (!mounted || result == null) return;
    final child = children.firstWhere(
      (item) => item['userId'] == result.values['childId'],
      orElse: () => <String, dynamic>{},
    );
    await _finishTransaction(
      result,
      successMessage:
          'Transfer berhasil: '
          '${_rupiah(result.values['amount'])} untuk ${child['name'] ?? 'anak'}. '
          'Saldo bertambah setelah child mengonfirmasi.',
      uncertainMessage:
          'Status transfer belum dapat dipastikan. '
          'Periksa riwayat sebelum mencoba lagi.',
    );
  }

  Future<void> _createExpense() async {
    if (_categories.isEmpty) {
      _message('Belum ada kategori pengeluaran aktif.');
      return;
    }
    final result = await showDialog<_TransactionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseDialog(
        categories: _categories,
        onSubmit: (data) async {
          await widget.api.post('/expenses', {
            'categoryId': data['categoryId'],
            'amount': data['amount'],
            if (data['description']!.trim().isNotEmpty)
              'description': data['description']!.trim(),
          });
        },
      ),
    );
    if (!mounted || result == null) return;
    final category = _categories.firstWhere(
      (item) => item['id'] == result.values['categoryId'],
      orElse: () => <String, dynamic>{},
    );
    await _finishTransaction(
      result,
      successMessage:
          'Pengeluaran berhasil dicatat: '
          '${_rupiah(result.values['amount'])} untuk '
          '${category['name'] ?? 'kategori'}.',
      uncertainMessage:
          'Status pengeluaran belum dapat dipastikan. '
          'Periksa riwayat sebelum mencoba lagi.',
    );
  }

  Future<void> _finishTransaction(
    _TransactionDialogResult result, {
    required String successMessage,
    required String uncertainMessage,
  }) async {
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    _message(result.succeeded ? successMessage : uncertainMessage);
  }

  Future<void> _voidExpense(String id) async {
    final reason = await _textDialog(
      title: 'Batalkan pengeluaran',
      label: 'Alasan wajib diisi',
    );
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      _message('Masukkan alasan pembatalan.');
      return;
    }
    await _perform(
      () async =>
          widget.api.patch('/expenses/$id/void', {'reason': reason.trim()}),
      successMessage: 'Pengeluaran dibatalkan dan saldo dihitung ulang.',
    );
  }

  Future<void> _markNotificationRead(String id) =>
      _perform(() async => widget.api.patch('/notifications/$id/read'));

  @override
  Widget build(BuildContext context) {
    final titles = ['Ringkasan', 'Riwayat', 'Notifikasi', 'Akun'];
    final pages = [
      _overview(),
      _transactions(),
      _notificationList(),
      _profile(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifikasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
      floatingActionButton: !_loading && (_isParent || _isChild)
          ? FloatingActionButton.extended(
              onPressed: _working
                  ? null
                  : (_isParent ? _createTransfer : _createExpense),
              icon: Icon(_isParent ? Icons.send : Icons.add_card),
              label: Text(_isParent ? 'Transfer' : 'Pengeluaran'),
            )
          : null,
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _overview() {
    if (_isAdmin) return _adminFamilies();
    final totals = _map(_report['totals']);
    final familyName = _family['name']?.toString() ?? 'Family';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text(
            'Halo, ${widget.user['name'] ?? 'Pengguna'}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            familyName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _balanceCard(totals),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Pemasukan',
                  totals['confirmedIncome'],
                  Icons.south_west,
                  const Color(0xFF176B55),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Pengeluaran',
                  totals['activeExpenses'],
                  Icons.north_east,
                  const Color(0xFFB64B46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _monthlyCard(),
          if (_isParent) ...[
            const SizedBox(height: 24),
            _sectionTitle('Saldo anak'),
            ..._maps(_report['children']).map(_childBalanceCard),
          ],
          const SizedBox(height: 24),
          _sectionTitle(_isChild ? 'Transfer menunggu' : 'Transfer terbaru'),
          ..._transfers.take(5).map(_transferCard),
          if (_transfers.isEmpty) _emptyMessage('Belum ada transfer.'),
          const SizedBox(height: 16),
          _sectionTitle('Pengeluaran terbaru'),
          ..._expenses.take(5).map(_expenseCard),
          if (_expenses.isEmpty) _emptyMessage('Belum ada pengeluaran.'),
        ],
      ),
    );
  }

  Widget _adminFamilies() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Keluarga terdaftar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (_families.isEmpty) _emptyMessage('Belum ada family.'),
        ..._families.map(
          (family) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.family_restroom)),
              title: Text(family['name']?.toString() ?? 'Family'),
              subtitle: Text('${family['_count']?['children'] ?? 0} anak'),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _transactions() {
    if (_isAdmin) {
      return _emptyMessage('Admin belum memiliki riwayat transaksi family.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _sectionTitle('Semua aktivitas terbaru'),
          if (_history.isEmpty) _emptyMessage('Belum ada transaksi.'),
          ..._history.map(_historyCard),
        ],
      ),
    );
  }

  Widget _notificationList() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_notifications.isEmpty) _emptyMessage('Belum ada notifikasi.'),
        ..._notifications.map((notification) {
          final read = notification['isRead'] == true;
          return Card(
            child: ListTile(
              leading: Icon(
                read
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
              ),
              title: Text(notification['title']?.toString() ?? 'Notifikasi'),
              subtitle: Text(notification['message']?.toString() ?? ''),
              trailing: read
                  ? null
                  : IconButton(
                      tooltip: 'Tandai dibaca',
                      icon: const Icon(Icons.check),
                      onPressed: () =>
                          _markNotificationRead(notification['id'].toString()),
                    ),
            ),
          );
        }),
      ],
    ),
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(widget.user['name']?.toString() ?? 'Pengguna'),
          subtitle: Text('${widget.user['email'] ?? ''}\n${_roleLabel(_role)}'),
          isThreeLine: true,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _working ? null : widget.onSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
      ),
    ],
  );

  Widget _balanceCard(Map<String, dynamic> totals) => Card(
    color: Theme.of(context).colorScheme.primary,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo saat ini',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary
                  .withValues(alpha: .8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _rupiah(totals['balance']),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer dihitung setelah dikonfirmasi child.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary
                  .withValues(alpha: .8),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statCard(String title, dynamic amount, IconData icon, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                _rupiah(amount),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );

  Widget _monthlyCard() {
    final totals = _map(_monthlyReport['totals']);
    final breakdown = _maps(_monthlyReport['expensesByCategory']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan bulan ini',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _monthlyValue('Pemasukan', totals['confirmedIncome']),
                ),
                Expanded(
                  child: _monthlyValue('Pengeluaran', totals['activeExpenses']),
                ),
                Expanded(child: _monthlyValue('Selisih', totals['net'])),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Pengeluaran per kategori',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...breakdown
                  .take(5)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['categoryName']?.toString() ?? 'Kategori',
                            ),
                          ),
                          Text(
                            _rupiah(item['amount']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthlyValue(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          _rupiah(value),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _childBalanceCard(Map<String, dynamic> child) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.child_care)),
      title: Text(child['name']?.toString() ?? 'Child'),
      subtitle: Text(
        child['walletActive'] == true ? 'Wallet aktif' : 'Wallet tidak aktif',
      ),
      trailing: Text(
        _rupiah(child['balance']),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _transferCard(Map<String, dynamic> transfer) {
    final status = transfer['status']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Color(0xFF176B55)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _rupiah(transfer['amount']),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            if (transfer['note'] != null &&
                transfer['note'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4),
                child: Text(transfer['note'].toString()),
              ),
            if (_isChild && status == 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _working
                          ? null
                          : () => _rejectTransfer(transfer['id'].toString()),
                      child: const Text('Belum masuk'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _working
                          ? null
                          : () => _confirmTransfer(transfer['id'].toString()),
                      child: const Text('Sudah masuk'),
                    ),
                  ],
                ),
              ),
            if (_isParent && status == 'PENDING')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _working
                      ? null
                      : () => _cancelTransfer(transfer['id'].toString()),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Batalkan'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final status = expense['status']?.toString() ?? '';
    final category = _map(expense['category']);
    final child = _map(expense['child']);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        title: Text(
          _rupiah(expense['amount']),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${category['name'] ?? 'Pengeluaran'}${_isParent && child['name'] != null ? ' • ${child['name']}' : ''}${expense['description'] == null ? '' : '\n${expense['description']}'}',
        ),
        isThreeLine: expense['description'] != null,
        trailing: _isParent && status == 'ACTIVE'
            ? IconButton(
                tooltip: 'Void',
                onPressed: _working
                    ? null
                    : () => _voidExpense(expense['id'].toString()),
                icon: const Icon(Icons.undo),
              )
            : _statusChip(status),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final transfer = item['type'] == 'TRANSFER';
    final title = transfer
        ? 'Transfer • ${item['child'] ?? ''}'
        : '${item['category'] ?? 'Pengeluaran'} • ${item['child'] ?? ''}';
    final description = item['description']?.toString();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            transfer ? Icons.swap_horiz : Icons.receipt_long_outlined,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          '${_roleLabel(item['status']?.toString() ?? '')}${description == null || description.isEmpty ? '' : '\n$description'}',
        ),
        isThreeLine: description != null && description.isNotEmpty,
        trailing: Text(
          _rupiah(item['amount']),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'CONFIRMED' || 'ACTIVE' => const Color(0xFF176B55),
      'REJECTED' || 'CANCELLED' || 'VOIDED' => const Color(0xFFB64B46),
      _ => const Color(0xFF8A6500),
    };
    return Chip(
      label: Text(_roleLabel(status)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .1),
      labelStyle: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      value,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _emptyMessage(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );

  String _rupiah(dynamic value) {
    final digits = int.tryParse(value?.toString() ?? '') ?? 0;
    final grouped = digits.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp ${digits < 0 ? '-' : ''}$grouped';
  }

  String _roleLabel(String value) => switch (value) {
    'ADMIN' => 'Admin',
    'PARENT' => 'Parent',
    'CHILD' => 'Child',
    'PENDING' => 'Menunggu',
    'CONFIRMED' => 'Dikonfirmasi',
    'REJECTED' => 'Ditolak',
    'CANCELLED' => 'Dibatalkan',
    'ACTIVE' => 'Aktif',
    'VOIDED' => 'Dibatalkan parent',
    _ => value,
  };
}

typedef _TransactionSubmit = Future<void> Function(Map<String, String> values);

class _TransactionDialogResult {
  const _TransactionDialogResult({
    required this.values,
    required this.succeeded,
  });

  final Map<String, String> values;
  final bool succeeded;
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.children, required this.onSubmit});

  final List<Map<String, dynamic>> children;
  final _TransactionSubmit onSubmit;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _childId;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final values = <String, String>{
      'childId': _childId!,
      'amount': _amount.text,
      'note': _note.text,
    };
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(values);
      if (!mounted) return;
      Navigator.of(context)
          .pop(_TransactionDialogResult(values: values, succeeded: true));
    } on ApiException catch (error) {
      if (error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _submitting = false;
          });
        }
        return;
      }
      _completeWithUnknownStatus(values);
    } catch (_) {
      _completeWithUnknownStatus(values);
    }
  }

  void _completeWithUnknownStatus(Map<String, String> values) {
    if (!mounted) return;
    Navigator.of(context)
        .pop(_TransactionDialogResult(values: values, succeeded: false));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: const Text('Buat transfer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _childId,
            decoration: const InputDecoration(labelText: 'Anak'),
            items: widget.children
                .map(
                  (child) => DropdownMenuItem(
                    value: child['userId'].toString(),
                    child: Text(child['name']?.toString() ?? 'Child'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _childId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah (Rp)',
              prefixText: 'Rp ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('transaction-error')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting || _childId == null || _amount.text.isEmpty
              ? null
              : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kirim'),
        ),
      ],
    ),
  );
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.categories, required this.onSubmit});

  final List<Map<String, dynamic>> categories;
  final _TransactionSubmit onSubmit;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final values = <String, String>{
      'categoryId': _categoryId!,
      'amount': _amount.text,
      'description': _description.text,
    };
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(values);
      if (!mounted) return;
      Navigator.of(context)
          .pop(_TransactionDialogResult(values: values, succeeded: true));
    } on ApiException catch (error) {
      if (error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _submitting = false;
          });
        }
        return;
      }
      _completeWithUnknownStatus(values);
    } catch (_) {
      _completeWithUnknownStatus(values);
    }
  }

  void _completeWithUnknownStatus(Map<String, String> values) {
    if (!mounted) return;
    Navigator.of(context)
        .pop(_TransactionDialogResult(values: values, succeeded: false));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: const Text('Catat pengeluaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category['id'].toString(),
                    child: Text(category['name']?.toString() ?? 'Kategori'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah (Rp)',
              prefixText: 'Rp ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Keterangan'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('transaction-error')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting || _categoryId == null || _amount.text.isEmpty
              ? null
              : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    ),
  );
}
