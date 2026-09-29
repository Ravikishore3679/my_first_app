import 'package:flutter/material.dart';

import 'category_icon.dart';

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({
    super.key,
    required this.categories,
    required this.onAdd,
    required this.onDelete,
  });

  final List<String> categories;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final TextEditingController _newCatController = TextEditingController();
  late List<String> _localCategories;

  Future<void> _confirmAndDeleteCategory(String category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text('Are you sure you want to delete "$category"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    widget.onDelete(category);
    setState(() => _localCategories.remove(category));
  }

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  @override
  void dispose() {
    _newCatController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newCatController.text.trim();
    if (name.isEmpty) return;

    if (_localCategories.any((category) => category.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category already exists.')));
      return;
    }

    widget.onAdd(name);
    setState(() {
      _localCategories.add(name);
      _newCatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCatController,
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _localCategories.length,
                itemBuilder: (context, index) {
                  final category = _localCategories[index];
                  return ListTile(
                    leading: CategoryIcon(category: category),
                    title: Text(category),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmAndDeleteCategory(category),
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
