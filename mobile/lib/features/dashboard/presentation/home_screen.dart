import 'package:flutter/material.dart';

import '../../../features/auth/data/models/auth_user.dart';
import '../../../features/auth/presentation/account_page.dart';
import '../../../features/dashboard/logic/dashboard_feature.dart';
import '../../../features/dashboard/logic/dashboard_controller.dart';
import '../../../features/dashboard/presentation/widgets/recent_finance_flow_card.dart';
import '../../../features/expenses/data/models/expense.dart';
import '../../../features/expenses/logic/expense_controller.dart';
import '../../../features/expenses/presentation/widgets/create_expense_dialog.dart';
import '../../../features/family/data/models/family_info.dart';
import '../../../features/family/presentation/child_wallets_screen.dart';
import '../../../features/family/presentation/family_list_page.dart';
import '../../../features/history/presentation/widgets/history_card.dart';
import '../../../features/notifications/logic/notifications_controller.dart';
import '../../../features/notifications/presentation/notifications_page.dart';
import '../../../features/reports/presentation/monthly_report_card.dart';
import '../../../features/shared/presentation/transaction_dialog_outcome.dart';
import '../../../shared/widgets/finance_widgets.dart';
import '../../../features/transfers/data/models/transfer.dart';
import '../../../features/transfers/logic/transfer_controller.dart';
import '../../../features/transfers/presentation/widgets/create_transfer_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.feature,
    required this.user,
    required this.onSignOut,
  });

  final DashboardFeature feature;
  final AuthUser user;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  DashboardController get _dashboard => widget.feature.dashboard;
  TransferController get _transfers => widget.feature.transferActions;
  ExpenseController get _expenses => widget.feature.expenseActions;
  NotificationsController get _notifications => widget.feature.notificationActions;
  AuthUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _dashboard.load();
  }

  Future<void> _perform(Future<void> Function() action, {String? successMessage}) async {
    final error = await _dashboard.perform(action);
    if (!mounted) return;
    if (error != null) {
      _message(error);
    } else if (successMessage != null) {
      _message(successMessage);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<String?> _textDialog({required String title, required String label}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Lanjutkan')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _confirmTransfer(Transfer transfer) => _perform(
    () => _transfers.confirm(transfer.id),
    successMessage: 'Penerimaan transfer dikonfirmasi.',
  );

  Future<void> _rejectTransfer(Transfer transfer) async {
    final reason = await _textDialog(title: 'Tolak transfer', label: 'Alasan (opsional)');
    if (reason == null) return;
    await _perform(
      () => _transfers.reject(transfer.id, reason),
      successMessage: 'Transfer ditolak. Saldo tidak berubah.',
    );
  }

  Future<void> _cancelTransfer(Transfer transfer) => _perform(
    () => _transfers.cancel(transfer.id),
    successMessage: 'Transfer dibatalkan.',
  );

  Future<void> _voidExpense(Expense expense) async {
    final reason = await _textDialog(title: 'Batalkan pengeluaran', label: 'Alasan wajib diisi');
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      _message('Masukkan alasan pembatalan.');
      return;
    }
    await _perform(
      () => _expenses.voidExpense(expense.id, reason),
      successMessage: 'Pengeluaran dibatalkan dan saldo dihitung ulang.',
    );
  }

  Future<void> _createTransfer() async {
    final family = _dashboard.snapshot.family;
    if (family == null || family.children.isEmpty) {
      _message('Family ini belum memiliki child.');
      return;
    }
    final result = await showDialog<TransactionDialogOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTransferDialog(
        children: family.children,
        onSubmit: _transfers.create,
      ),
    );
    if (!mounted || result == null) return;
    await _dashboard.load();
    if (!mounted) return;
    final matchingChildren = family.children.where((item) => item.userId == result.values['childId']);
    final childName = matchingChildren.isEmpty ? 'anak' : matchingChildren.first.name;
    _message(
      result.succeeded
          ? 'Transfer berhasil: ${formatRupiah(result.values['amount'])} untuk $childName. Saldo bertambah setelah child mengonfirmasi.'
          : 'Status transfer belum dapat dipastikan. Periksa riwayat sebelum mencoba lagi.',
    );
  }

  Future<void> _createExpense() async {
    final categories = _dashboard.snapshot.categories;
    if (categories.isEmpty) {
      _message('Belum ada kategori pengeluaran aktif.');
      return;
    }
    final result = await showDialog<TransactionDialogOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateExpenseDialog(categories: categories, onSubmit: _expenses.create),
    );
    if (!mounted || result == null) return;
    await _dashboard.load();
    if (!mounted) return;
    final matchingCategories = categories.where((item) => item.id == result.values['categoryId']);
    final categoryName = matchingCategories.isEmpty ? 'kategori' : matchingCategories.first.name;
    _message(
      result.succeeded
          ? 'Pengeluaran berhasil dicatat: ${formatRupiah(result.values['amount'])} untuk $categoryName.'
          : 'Status pengeluaran belum dapat dipastikan. Periksa riwayat sebelum mencoba lagi.',
    );
  }

  Future<void> _markNotificationRead(String id) =>
      _perform(() => _notifications.markRead(id));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _dashboard,
    builder: (context, _) {
      const titles = ['Ringkasan', 'Riwayat', 'Notifikasi', 'Akun'];
      final pages = [
        _overview(),
        _transactions(),
        NotificationsPage(
          notifications: _dashboard.snapshot.notifications,
          onRefresh: _dashboard.load,
          onMarkRead: _markNotificationRead,
        ),
        AccountPage(user: _user, working: _dashboard.working, onSignOut: widget.onSignOut),
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(titles[_tab]),
          actions: [IconButton(tooltip: 'Muat ulang', onPressed: _dashboard.loading ? null : _dashboard.load, icon: const Icon(Icons.refresh))],
        ),
        body: _dashboard.loading
            ? const Center(child: CircularProgressIndicator())
            : _dashboard.error != null
                ? _errorView()
                : pages[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Riwayat'),
            NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifikasi'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
          ],
        ),
        floatingActionButton: !_dashboard.loading && (_dashboard.isParent || _dashboard.isChild)
            ? FloatingActionButton.extended(
                onPressed: _dashboard.working ? null : (_dashboard.isParent ? _createTransfer : _createExpense),
                icon: Icon(_dashboard.isParent ? Icons.send : Icons.add_card),
                label: Text(_dashboard.isParent ? 'Transfer' : 'Pengeluaran'),
              )
            : null,
      );
    },
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(_dashboard.error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _dashboard.load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
        ],
      ),
    ),
  );

  Widget _overview() {
    final data = _dashboard.snapshot;
    if (_dashboard.isAdmin) return FamilyListPage(families: data.families, onRefresh: _dashboard.load);
    final totals = data.overview?.totals ?? const <String, dynamic>{};
    final wallets = _childWallets();
    return RefreshIndicator(
      onRefresh: _dashboard.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text('Halo, ${_user.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(data.family?.name ?? 'Family', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          FinanceBalanceCard(totals: totals),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FinanceStatCard(title: 'Pemasukan', amount: totals['confirmedIncome'], icon: Icons.south_west, color: const Color(0xFF176B55))),
            const SizedBox(width: 12),
            Expanded(child: FinanceStatCard(title: 'Pengeluaran', amount: totals['activeExpenses'], icon: Icons.north_east, color: const Color(0xFFB64B46))),
          ]),
          const SizedBox(height: 20),
          MonthlyReportCard(report: data.monthlyReport),
          if (_dashboard.isParent) ...[
            const SizedBox(height: 12),
            _totalChildWalletCard(wallets),
          ],
          const SizedBox(height: 12),
          RecentFinanceFlowCard(
            transfers: data.transfers,
            expenses: data.expenses,
            isParent: _dashboard.isParent,
            isChild: _dashboard.isChild,
            working: _dashboard.working,
            onConfirmTransfer: _confirmTransfer,
            onRejectTransfer: _rejectTransfer,
            onCancelTransfer: _cancelTransfer,
            onVoidExpense: _voidExpense,
            onShowHistory: () => setState(() => _tab = 1),
          ),
        ],
      ),
    );
  }

  List<ChildWalletSummary> _childWallets() {
    final balances = {
      for (final child in _dashboard.snapshot.overview?.children ?? const <Map<String, dynamic>>[])
        child['childId']?.toString(): child,
    };
    return (_dashboard.snapshot.family?.children ?? const <FamilyChild>[])
        .where((child) => child.walletName != null)
        .map((child) => ChildWalletSummary(
          childId: child.userId,
          name: child.name,
          walletName: child.walletName ?? 'Wallet Utama',
          walletActive: child.walletActive,
          balance: balances[child.userId]?['balance']?.toString(),
        ))
        .toList();
  }

  Widget _totalChildWalletCard(List<ChildWalletSummary> wallets) {
    final balances = wallets.map((wallet) => int.tryParse(wallet.balance ?? '')).toList();
    final total = balances.any((value) => value == null)
        ? null
        : balances.fold<int>(0, (sum, value) => sum + value!);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => ChildWalletsScreen(wallets: wallets))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.onSecondaryContainer)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Wallet Anak', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${wallets.length} anak memiliki wallet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(total == null ? 'Saldo belum tersedia' : formatRupiah(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactions() {
    if (_dashboard.isAdmin) return const EmptyMessage('Admin belum memiliki riwayat transaksi family.');
    final history = _dashboard.snapshot.history?.items ?? const [];
    return RefreshIndicator(
      onRefresh: _dashboard.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          const SectionTitle('Semua aktivitas terbaru'),
          if (history.isEmpty) const EmptyMessage('Belum ada transaksi.'),
          ...history.map((entry) => HistoryCard(entry: entry)),
        ],
      ),
    );
  }
}
