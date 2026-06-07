import 'package:flutter/material.dart';

import '../../models/catalog/catalog_category.dart';
import '../../utils/app_spacing.dart';
import '../../utils/hebrew_strings.dart';

/// Searchable full category list (all imported categories).
/// Returns selected category id, empty string for “all”, or null if dismissed.
Future<String?> showCatalogCategoryPicker({
  required BuildContext context,
  required List<CatalogCategory> categories,
  String? selectedCategoryId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => CatalogCategoryPickerSheet(
      categories: categories,
      selectedCategoryId: selectedCategoryId,
    ),
  );
}

class CatalogCategoryPickerSheet extends StatefulWidget {
  const CatalogCategoryPickerSheet({
    super.key,
    required this.categories,
    this.selectedCategoryId,
  });

  final List<CatalogCategory> categories;
  final String? selectedCategoryId;

  @override
  State<CatalogCategoryPickerSheet> createState() =>
      _CatalogCategoryPickerSheetState();
}

class _CatalogCategoryPickerSheetState extends State<CatalogCategoryPickerSheet> {
  late final TextEditingController _filterController;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<CatalogCategory> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return widget.categories;
    return widget.categories
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.nameLower.contains(q) ||
              c.id.contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final filtered = _filtered;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  HebrewStrings.catalogAllCategoriesPicker,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: HebrewStrings.catalogSearchCategories,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  HebrewStrings.catalogCategoriesCount(filtered.length),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          HebrewStrings.catalogCategoriesEmpty,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: const Icon(Icons.layers_clear_outlined),
                              title: Text(HebrewStrings.allCategories),
                              selected: widget.selectedCategoryId == null,
                              onTap: () => Navigator.pop(context, ''),
                            );
                          }
                          final cat = filtered[index - 1];
                          return ListTile(
                            title: Text(cat.name),
                            selected: cat.id == widget.selectedCategoryId,
                            trailing: cat.id == widget.selectedCategoryId
                                ? Icon(
                                    Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, cat.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
