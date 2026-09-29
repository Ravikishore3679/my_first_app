import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme/app_colors.dart';
import '../models/expense_entry.dart';
import '../viewmodels/expense_view_model.dart';
import 'budget_estimator_screen.dart';
import 'widgets/category_icon.dart';
import 'widgets/dashboard_mini_stat_card.dart';
import 'widgets/expense_dialog.dart';
import 'widgets/expense_receipt_sheet.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/manage_categories_dialog.dart';
import 'widgets/manage_sites_dialog.dart';
import 'widgets/site_expense_chart.dart';

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key, required this.viewModel, this.onLogout});

  final ExpenseViewModel viewModel;
  final VoidCallback? onLogout;

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  ExpenseViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final message = await vm.initialize();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _buildExpenseReceiptText(ExpenseEntry entry) {
    final buffer = StringBuffer();
    buffer.writeln('CONSTRUCTION EXPENSE RECEIPT');
    buffer.writeln('====================================');
    buffer.writeln('Amount: Rs. ${NumberFormat('#,##0').format(entry.amount)}');
    buffer.writeln('Category: ${entry.category}');
    buffer.writeln('Site: ${entry.site}');
    buffer.writeln(
      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(entry.date)}',
    );
    if (entry.description.trim().isNotEmpty) {
      buffer.writeln('Description: ${entry.description.trim()}');
    }
    buffer.writeln('Receipt No.: ${entry.id}');
    return buffer.toString();
  }

  Future<void> _shareExpenseReceipt(ExpenseEntry entry) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _buildExpenseReceiptText(entry),
        subject: 'Expense Receipt',
      ),
    );
  }

  Future<void> _showExpenseReceipt(ExpenseEntry entry) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ExpenseReceiptSheet(
        entry: entry,
        onPrint: () => _printExpenseReceipt(entry),
        onShare: () => _shareExpenseReceipt(entry),
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _printExpenseReceipt(ExpenseEntry entry) async {
    final document = pw.Document();
    final dateLabel = DateFormat('dd MMM yyyy, hh:mm a').format(entry.date);

    pw.Widget receiptRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 82,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
    }

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.brown900,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Construction Expense Tracker',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Expense Receipt',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Rs. ${NumberFormat('#,##0').format(entry.amount)}',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Saved successfully',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                pw.SizedBox(height: 8),
                receiptRow('Category', entry.category),
                receiptRow('Site', entry.site),
                receiptRow('Date', dateLabel),
                if (entry.description.trim().isNotEmpty)
                  receiptRow('Description', entry.description.trim()),
                pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Receipt No.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(entry.id, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Thank you',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.brown700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'expense_receipt_${entry.id}.pdf',
      onLayout: (_) async => document.save(),
    );
  }

  Future<void> _saveExpenseAndShowReceipt(ExpenseEntry entry) async {
    final message = await vm.addExpense(entry);
    if (!mounted) return;

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }

    await _showExpenseReceipt(entry);
  }

  Future<void> _updateExpenseAndShowReceipt(ExpenseEntry entry) async {
    final message = await vm.updateExpense(entry);
    if (!mounted) return;

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }

    await _showExpenseReceipt(entry);
  }

  Future<void> _logout() async {
    final message = await vm.signOutGoogle();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
    widget.onLogout?.call();
  }

  void _showAddExpenseDialog() {
    if (vm.sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one site first using Manage Sites.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ExpenseDialog(
        categories: vm.categories,
        sites: vm.sites,
        onSave: _saveExpenseAndShowReceipt,
      ),
    );
  }

  void _showEditExpenseDialog(ExpenseEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => ExpenseDialog(
        categories: vm.categories,
        sites: vm.sites,
        existingEntry: entry,
        onSave: _updateExpenseAndShowReceipt,
      ),
    );
  }

  void _showManageCategoriesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ManageCategoriesDialog(
        categories: vm.categories,
        onAdd: (name) => vm.addCategory(name),
        onDelete: (name) => vm.deleteCategory(name),
      ),
    );
  }

  void _showManageSitesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ManageSitesDialog(
        sites: vm.sites,
        onAdd: (name) => vm.addSite(name),
        onDelete: (name) => vm.deleteSite(name),
      ),
    );
  }

  Future<void> _shareReport() async {
    SharePlus.instance.share(
      ShareParams(
        text: vm.buildReportText(),
        subject: 'Construction Expense Report',
      ),
    );
  }

  Future<void> _printReport() async {
    final document = pw.Document();
    final reportText = vm.buildReportText();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Construction Expense Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            reportText,
            style: const pw.TextStyle(fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'construction_expense_report.pdf',
      onLayout: (_) async => document.save(),
    );
  }

  Widget _buildDashboardPage() {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kSandBackground, kSandSurface],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [kStonePrimary, kStoneSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x336D6558),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expenditure',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFF7EFE6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${vm.totalAmount}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${vm.entries.length} payments recorded',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE8D8C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    if (compact) {
                      return Column(
                        children: [
                          DashboardMiniStatCard(
                            title: 'Active Sites',
                            value: '${vm.totalSites}',
                            icon: Icons.location_city,
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 10),
                          DashboardMiniStatCard(
                            title: 'Today',
                            value: '₹${vm.todayAmount}',
                            icon: Icons.today,
                            color: const Color(0xFFDC2626),
                          ),
                          const SizedBox(height: 10),
                          DashboardMiniStatCard(
                            title: 'Overall Cost/SFT',
                            value:
                                '₹${vm.overallCostPerSft.toStringAsFixed(2)}',
                            icon: Icons.straighten,
                            color: const Color(0xFF059669),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: DashboardMiniStatCard(
                            title: 'Active Sites',
                            value: '${vm.totalSites}',
                            icon: Icons.location_city,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DashboardMiniStatCard(
                            title: 'Today',
                            value: '₹${vm.todayAmount}',
                            icon: Icons.today,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DashboardMiniStatCard(
                            title: 'Overall Cost/SFT',
                            value:
                                '₹${vm.overallCostPerSft.toStringAsFixed(2)}',
                            icon: Icons.straighten,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sunny, color: kStonePrimary),
                            SizedBox(width: 8),
                            Text(
                              "Today's Expenses",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (vm.todayEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'No expenses today',
                              style: TextStyle(color: Colors.black45),
                            ),
                          )
                        else ...[
                          Text(
                            'Total: ₹${vm.todayAmount}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kStonePrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(vm.todayEntries.length, (index) {
                            final entry = vm.todayEntries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${entry.category} (${entry.site})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (entry.description.isNotEmpty)
                                          Text(
                                            entry.description,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${entry.amount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kStonePrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: kStonePrimary),
                            SizedBox(width: 8),
                            Text(
                              'Expenses By Site',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (vm.entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No expense data available for site chart.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else ...[
                          SiteExpenseChart(
                            siteTotals: vm.siteTotals,
                            siteSftValues: vm.siteSftValues,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesPage() {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              decoration: BoxDecoration(
                color: kSandSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14A58F6D)),
              ),
              child: vm.entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No expenses recorded yet. Use Add Expense above.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      itemCount: vm.entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = vm.entries[index];
                        return ListTile(
                          leading: CategoryIcon(category: entry.category),
                          title: Text(
                            '${entry.category} (${entry.site})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.description.isNotEmpty)
                                Text(
                                  entry.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                entry.formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${entry.amount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: kStoneAccent,
                                ),
                                tooltip: 'Edit',
                                onPressed: () => _showEditExpenseDialog(entry),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetPage() {
    return BudgetEstimatorScreen(viewModel: vm);
  }

  Widget _buildReportsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: vm.filterCategory,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...vm.categories.map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: vm.setFilterCategory,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: vm.filterSite,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Sites'),
                        ),
                        ...vm.availableSites.map(
                          (site) =>
                              DropdownMenuItem(value: site, child: Text(site)),
                        ),
                      ],
                      onChanged: vm.setFilterSite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      vm.filterStartDate == null
                          ? 'From'
                          : DateFormat('dd/MM').format(vm.filterStartDate!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: vm.filterStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        vm.setFilterStartDate(picked);
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      vm.filterEndDate == null
                          ? 'To'
                          : DateFormat('dd/MM').format(vm.filterEndDate!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: vm.filterEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        vm.setFilterEndDate(picked);
                      }
                    },
                  ),
                  OutlinedButton(
                    onPressed: vm.clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFFF4EBDD),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Summary',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rs. ${vm.filteredTotal}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kStonePrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${vm.filteredEntries.length} entries found',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        if (vm.filterCategory != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Category: ${vm.filterCategory}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (vm.filterSite != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Site: ${vm.filterSite}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _printReport,
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Print Report'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _shareReport,
                              icon: const Icon(Icons.ios_share_outlined),
                              label: const Text('Share Report'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (vm.filteredEntries.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No expenses match your filters. Adjust and try again.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: vm.filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = vm.filteredEntries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CategoryIcon(category: entry.category),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.category} (${entry.site})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (entry.description.isNotEmpty)
                                        Text(
                                          entry.description,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      Text(
                                        'Receipt No.: ${entry.id}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                      ),
                                      Text(
                                        entry.formattedDate,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rs. ${entry.amount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final pages = [
          _buildDashboardPage(),
          _buildExpensesPage(),
          _buildReportsPage(),
          _buildBudgetPage(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Construction Expense Tracker'),
            centerTitle: true,
            foregroundColor: Colors.white,
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
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(
                  vm.cloudStore.isEnabled
                      ? Icons.cloud_done
                      : (vm.cloudStore.isConfigured
                            ? Icons.cloud_queue
                            : Icons.cloud_off),
                  size: 20,
                  color: const Color(0xFFF7EFE6),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
              if (vm.selectedIndex == 2)
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Print report',
                  onPressed: _printReport,
                ),
              if (vm.selectedIndex == 2)
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Share report',
                  onPressed: _shareReport,
                ),
              IconButton(
                icon: const Icon(Icons.category),
                tooltip: 'Manage categories',
                onPressed: _showManageCategoriesDialog,
              ),
              IconButton(
                icon: const Icon(Icons.location_on),
                tooltip: 'Manage sites',
                onPressed: _showManageSitesDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              if (!vm.cloudStore.isConfigured)
                MaterialBanner(
                  backgroundColor: const Color(0xFFF4EBDD),
                  content: Text(
                    'Firebase config missing: ${vm.cloudStore.missingRunValues.join(', ')}',
                    style: const TextStyle(color: kStoneText),
                  ),
                  actions: const [SizedBox.shrink()],
                ),
              Expanded(child: pages[vm.selectedIndex]),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: vm.selectedIndex,
            onDestinationSelected: vm.setSelectedIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                label: 'Budget',
              ),
            ],
          ),
        );
      },
    );
  }
}
