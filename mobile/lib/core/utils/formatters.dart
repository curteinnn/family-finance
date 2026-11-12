String formatRupiah(dynamic value, {String fallback = 'Rp 0'}) {
  final digits = int.tryParse(value?.toString() ?? '');
  if (digits == null) return fallback;
  final grouped = digits.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp ${digits < 0 ? '-' : ''}$grouped';
}

String formatShortDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String roleLabel(String value) => switch (value) {
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
