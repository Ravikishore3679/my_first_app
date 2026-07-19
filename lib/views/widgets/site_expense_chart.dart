import 'package:flutter/material.dart';

class SiteExpenseChart extends StatelessWidget {
  const SiteExpenseChart({super.key, required this.siteTotals});

  final Map<String, int> siteTotals;

  @override
  Widget build(BuildContext context) {
    final sorted = siteTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = sorted.first.value;
    const palette = <Color>[
      Color(0xFF0EA5A1),
      Color(0xFF2563EB),
      Color(0xFFF97316),
      Color(0xFF7C3AED),
      Color(0xFFDC2626),
      Color(0xFF16A34A),
    ];

    return Column(
      children: List.generate(sorted.length, (index) {
        final entry = sorted[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _SiteBarRow(
            siteName: entry.key,
            amount: entry.value,
            maxAmount: highest,
            barColor: palette[index % palette.length],
          ),
        );
      }),
    );
  }
}

class _SiteBarRow extends StatelessWidget {
  const _SiteBarRow({
    required this.siteName,
    required this.amount,
    required this.maxAmount,
    required this.barColor,
  });

  final String siteName;
  final int amount;
  final int maxAmount;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount <= 0 ? 0.0 : amount / maxAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                siteName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹$amount',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * ratio.clamp(0.0, 1.0);
              return Stack(
                children: [
                  Container(
                    height: 12,
                    color: barColor.withValues(alpha: 0.18),
                  ),
                  Container(
                    height: 12,
                    width: width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.78), barColor],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
