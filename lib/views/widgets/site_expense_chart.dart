import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SiteExpenseChart extends StatelessWidget {
  const SiteExpenseChart({
    super.key,
    required this.siteTotals,
    this.siteSftValues = const {},
  });

  final Map<String, int> siteTotals;
  final Map<String, double> siteSftValues;

  @override
  Widget build(BuildContext context) {
    final sorted = siteTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = sorted.first.value;
    const palette = <Color>[
      kStonePrimary,
      kStoneSecondary,
      kStoneAccent,
      Color(0xFFB89A6C),
      Color(0xFF8C7A5B),
      Color(0xFF6D6558),
    ];

    return Column(
      children: List.generate(sorted.length, (index) {
        final entry = sorted[index];
        final siteSft = siteSftValues[entry.key] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _SiteBarRow(
            siteName: entry.key,
            amount: entry.value,
            perSft: siteSft > 0 ? entry.value / siteSft : null,
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
    required this.perSft,
    required this.maxAmount,
    required this.barColor,
  });

  final String siteName;
  final int amount;
  final double? perSft;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (perSft != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kStonePrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kStonePrimary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '₹${perSft!.toStringAsFixed(2)}/SFT',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kStonePrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
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
