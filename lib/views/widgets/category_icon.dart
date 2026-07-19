import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.orange.shade100,
      child: Icon(
        _iconForCategory(category),
        color: Colors.orange.shade900,
        size: 20,
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sand':
        return Icons.landscape;
      case 'gravel':
        return Icons.grass;
      case 'bricks':
        return Icons.dns;
      case 'steel':
        return Icons.build;
      case 'cement':
        return Icons.format_paint;
      case 'labour':
        return Icons.groups;
      case 'electrical':
        return Icons.electrical_services;
      case 'plumbing':
        return Icons.plumbing;
      default:
        return Icons.category;
    }
  }
}
