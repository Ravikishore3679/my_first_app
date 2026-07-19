import 'package:flutter/material.dart';

class ManageSitesDialog extends StatefulWidget {
  const ManageSitesDialog({
    super.key,
    required this.sites,
    required this.onAdd,
    required this.onDelete,
  });

  final List<String> sites;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  @override
  State<ManageSitesDialog> createState() => _ManageSitesDialogState();
}

class _ManageSitesDialogState extends State<ManageSitesDialog> {
  final TextEditingController _newSiteController = TextEditingController();
  late List<String> _localSites;

  @override
  void initState() {
    super.initState();
    _localSites = List.from(widget.sites);
  }

  @override
  void dispose() {
    _newSiteController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newSiteController.text.trim();
    if (name.isEmpty) return;

    if (_localSites.any((site) => site.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Site already exists.')));
      return;
    }

    widget.onAdd(name);
    setState(() {
      _localSites.add(name);
      _newSiteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Sites'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSiteController,
                    decoration: const InputDecoration(
                      labelText: 'New site name',
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
                itemCount: _localSites.length,
                itemBuilder: (context, index) {
                  final site = _localSites[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(site),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        widget.onDelete(site);
                        setState(() => _localSites.remove(site));
                      },
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
