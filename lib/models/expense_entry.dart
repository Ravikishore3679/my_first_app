class ExpenseEntry {
  ExpenseEntry({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.site,
    required this.date,
  });

  final String id;
  final String category;
  final int amount;
  final String description;
  final String site;
  final DateTime date;

    String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'amount': amount,
    'description': description,
    'site': site,
    'date': date.toIso8601String(),
  };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is int
        ? rawAmount
        : rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final rawDate = json['date']?.toString();
    final parsedDate = rawDate == null
        ? DateTime.now()
        : DateTime.tryParse(rawDate) ?? DateTime.now();

    return ExpenseEntry(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      category: json['category']?.toString() ?? '',
      amount: amount,
      description: json['description']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      date: parsedDate,
    );
  }

  ExpenseEntry copyWith({
    String? category,
    int? amount,
    String? description,
    String? site,
  }) => ExpenseEntry(
    id: id,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    site: site ?? this.site,
    date: date,
  );
}
