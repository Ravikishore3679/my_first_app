import 'expense_entry.dart';

class CloudSnapshot {
  const CloudSnapshot({
    required this.categories,
    required this.sites,
    required this.entries,
  });

  final List<String> categories;
  final List<String> sites;
  final List<ExpenseEntry> entries;
}
