import 'package:flutter/material.dart';

import '../../models/expense_entry.dart';

class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({
    super.key,
    required this.categories,
    required this.sites,
    required this.onSave,
    this.existingEntry,
  });

  final List<String> categories;
  final List<String> sites;
  final ValueChanged<ExpenseEntry> onSave;
  final ExpenseEntry? existingEntry;

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _selectedCategory;
  late String _selectedSite;

  bool get _isEdit => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _amountController = TextEditingController(
      text: existing != null ? '${existing.amount}' : '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );

    final existingCategory = existing?.category.trim() ?? '';
    final hasExistingCategory =
        existingCategory.isNotEmpty && widget.categories.contains(existingCategory);
    _selectedCategory = hasExistingCategory
        ? existingCategory
        : (widget.categories.isNotEmpty ? widget.categories.first : '');

    final existingSite = existing?.site.trim() ?? '';
    final hasExistingSite = existingSite.isNotEmpty && widget.sites.contains(existingSite);
    _selectedSite =
        hasExistingSite ? existingSite : (widget.sites.isNotEmpty ? widget.sites.first : '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }

    if (_selectedSite.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site.')));
      return;
    }

    final entry = _isEdit
        ? widget.existingEntry!.copyWith(
            category: _selectedCategory,
            amount: amount,
            description: _descriptionController.text.trim(),
            site: _selectedSite.trim(),
          )
        : ExpenseEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            category: _selectedCategory,
            amount: amount,
            description: _descriptionController.text.trim(),
            site: _selectedSite.trim(),
            date: DateTime.now(),
          );

    widget.onSave(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryValue =
        widget.categories.contains(_selectedCategory) ? _selectedCategory : null;
    final selectedSiteValue = widget.sites.contains(_selectedSite) ? _selectedSite : null;

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedCategoryValue,
              items: widget.categories
                  .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Payment type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSiteValue,
              items: widget.sites
                  .map((site) => DropdownMenuItem(value: site, child: Text(site)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSite = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Site',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
