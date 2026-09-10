import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/expense_entry.dart';
import '../viewmodels/expense_view_model.dart';

class BudgetCategoryRow {
  BudgetCategoryRow({
    required String name,
    required double totalCost,
  }) : nameController = TextEditingController(text: name),
       costController = TextEditingController(
         text: totalCost == 0 ? '' : totalCost.toStringAsFixed(0),
       );

  final TextEditingController nameController;
  final TextEditingController costController;

  String get name => nameController.text.trim();

  double get totalCost {
    final value = costController.text.replaceAll(',', '').trim();
    return double.tryParse(value) ?? 0;
  }

  void dispose() {
    nameController.dispose();
    costController.dispose();
  }
}

class BudgetEstimatorScreen extends StatefulWidget {
  const BudgetEstimatorScreen({
    super.key,
    required this.viewModel,
  });

  final ExpenseViewModel viewModel;

  @override
  State<BudgetEstimatorScreen> createState() => _BudgetEstimatorScreenState();
}

class _BudgetEstimatorScreenState extends State<BudgetEstimatorScreen> {
  final TextEditingController _totalSftController =
      TextEditingController(text: '100');

  String? _selectedSite;
  List<BudgetCategoryRow> _categories = const [];
  final Map<String, Map<String, double>> _siteCategoryTotals = {};

  @override
  void initState() {
    super.initState();
    _selectedSite = widget.viewModel.sites.isNotEmpty ? widget.viewModel.sites.first : null;
    _syncCategoriesForSelectedSite();
  }

  @override
  void didUpdateWidget(covariant BudgetEstimatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel ||
        oldWidget.viewModel.entries.length != widget.viewModel.entries.length ||
        oldWidget.viewModel.sites.length != widget.viewModel.sites.length) {
      final availableSites = widget.viewModel.sites;
      if (_selectedSite == null || !availableSites.contains(_selectedSite)) {
        _selectedSite = availableSites.isNotEmpty ? availableSites.first : null;
      }
      _syncCategoriesForSelectedSite();
    }
  }

  Map<String, double> _siteExpenseTotals() {
    final totals = <String, double>{};
    if (_selectedSite == null || _selectedSite!.trim().isEmpty) {
      return totals;
    }

    for (final entry in widget.viewModel.entries) {
      if (entry.site != _selectedSite) continue;
      final category = entry.category.trim();
      if (category.isEmpty) continue;
      totals[category] = (totals[category] ?? 0) + entry.amount;
    }
    return totals;
  }

  void _saveCurrentSiteCategoryValues() {
    final siteName = (_selectedSite ?? '').trim();
    if (siteName.isEmpty) return;

    final values = <String, double>{};
    for (final row in _categories) {
      final name = row.name.trim();
      if (name.isEmpty) continue;
      final total = row.totalCost;
      if (total > 0) {
        values[name] = total;
      }
    }

    _siteCategoryTotals[siteName] = values;
  }

  void _saveCurrentSiteSft() {
    final siteName = (_selectedSite ?? '').trim();
    if (siteName.isEmpty) return;
    widget.viewModel.setSiteSftValue(siteName, _totalSftController.text);
  }

  void _applySiteSftValue(String? site) {
    final siteName = (site ?? '').trim();
    final savedValue = siteName.isEmpty ? null : widget.viewModel.siteSftValues[siteName];
    final value = savedValue != null ? savedValue.toStringAsFixed(0) : '100';
    if (_totalSftController.text != value) {
      _totalSftController.text = value;
    }
  }

  void _syncCategoriesForSelectedSite() {
    final siteTotals = _siteExpenseTotals();
    final siteName = (_selectedSite ?? '').trim();
    final savedSiteTotals = _siteCategoryTotals[siteName] ?? <String, double>{};

    final names = <String>{};
    for (final category in siteTotals.keys) {
      names.add(category.trim());
    }
    for (final category in savedSiteTotals.keys) {
      final trimmed = category.trim();
      if (trimmed.isNotEmpty && (savedSiteTotals[trimmed] ?? 0) > 0) {
        names.add(trimmed);
      }
    }

    final rows = <BudgetCategoryRow>[];
    for (final name in names) {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) continue;
      final total = siteTotals[normalizedName] ?? savedSiteTotals[normalizedName] ?? 0;
      if (total <= 0) continue;
      rows.add(BudgetCategoryRow(name: normalizedName, totalCost: total));
    }

    _categories = rows;
    if (siteName.isNotEmpty) {
      _siteCategoryTotals[siteName] = {
        for (final row in rows) row.name: row.totalCost,
      };
    }
    _applySiteSftValue(siteName.isEmpty ? null : siteName);
  }

  double get _totalEstimatedSft {
    final value = _totalSftController.text.replaceAll(',', '').trim();
    if (value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }

  double _costPerSft(BudgetCategoryRow row) {
    final sft = _totalEstimatedSft;
    if (sft <= 0) return 0;
    return row.totalCost / sft;
  }

  double get _grandTotal {
    return _categories.fold<double>(0, (sum, item) => sum + item.totalCost);
  }

  double get _overallCostPerSft {
    final sft = _totalEstimatedSft;
    if (sft <= 0) return 0;
    return _grandTotal / sft;
  }

  void _onSiteChanged(String? value) {
    if (value == null) return;
    _saveCurrentSiteCategoryValues();
    _saveCurrentSiteSft();
    setState(() {
      _selectedSite = value;
      _syncCategoriesForSelectedSite();
    });
  }

  String _formatNumber(num value) {
    return NumberFormat('#,##0.##').format(value);
  }

  @override
  void dispose() {
    _totalSftController.dispose();
    for (final item in _categories) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSandBackground,
      appBar: AppBar(
        title: const Text('Budget Estimator'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [kStonePrimary, kStoneSecondary],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kStoneText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSite,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'SITE',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              items: widget.viewModel.sites
                                  .map(
                                    (site) => DropdownMenuItem(
                                      value: site,
                                      child: Text(site),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onSiteChanged,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _totalSftController,
                              onChanged: (_) {
                                _saveCurrentSiteSft();
                                setState(() {});
                              },
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Total Estimated SFT',
                                hintText: '100',
                                prefixIcon: Icon(Icons.straighten),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Material Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kStoneText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 700;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: isCompact ? 560 : constraints.maxWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 18,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kStoneText,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Category Name')),
                                  DataColumn(label: Text('Total Cost')),
                                  DataColumn(label: Text('Cost per SFT')),
                                ],
                                rows: List<DataRow>.generate(
                                  _categories.length,
                                  (index) {
                                    final item = _categories[index];
                                    final costPerSft = _costPerSft(item);

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          TextFormField(
                                            controller: item.nameController,
                                            onChanged: (_) {
                                              _saveCurrentSiteCategoryValues();
                                              setState(() {});
                                            },
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          TextFormField(
                                            controller: item.costController,
                                            onChanged: (_) {
                                              _saveCurrentSiteCategoryValues();
                                              setState(() {});
                                            },
                                            keyboardType: const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _totalEstimatedSft <= 0
                                                  ? '0'
                                                  : _formatNumber(costPerSft),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: const Color(0xFFF4EBDD),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kStoneText,
                            ),
                          ),
                          if (_selectedSite != null && _selectedSite!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _selectedSite!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kStonePrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(
                              fontSize: 15,
                              color: kStoneText,
                            ),
                          ),
                          Text(
                            '₹${_formatNumber(_grandTotal)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kStonePrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall Cost per SFT',
                            style: TextStyle(
                              fontSize: 15,
                              color: kStoneText,
                            ),
                          ),
                          Text(
                            _totalEstimatedSft <= 0
                                ? '0'
                                : _formatNumber(_overallCostPerSft),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kStonePrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
