import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/supplier_directory_provider.dart';
import '../services/supplier_directory_service.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/supplier_targeting_helpers.dart';

class SupplierTargetSelection {
  const SupplierTargetSelection({
    required this.ids,
    required this.names,
  });

  final List<String> ids;
  final List<String> names;
}

class RfqSupplierTargetPicker extends ConsumerStatefulWidget {
  const RfqSupplierTargetPicker({
    super.key,
    required this.selectedIds,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final List<String> selectedNames;
  final ValueChanged<SupplierTargetSelection> onChanged;

  @override
  ConsumerState<RfqSupplierTargetPicker> createState() =>
      _RfqSupplierTargetPickerState();
}

class _RfqSupplierTargetPickerState extends ConsumerState<RfqSupplierTargetPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSelected(AppUser supplier) =>
      widget.selectedIds.contains(supplier.id) ||
      widget.selectedNames.any(
        (name) =>
            name.trim().toLowerCase() == supplier.fullName.trim().toLowerCase(),
      );

  void _toggle(AppUser supplier, bool checked) {
    final ids = [...widget.selectedIds];
    final names = [...widget.selectedNames];
    if (checked) {
      if (!ids.contains(supplier.id)) ids.add(supplier.id);
      if (!names.any(
        (n) => n.trim().toLowerCase() == supplier.fullName.trim().toLowerCase(),
      )) {
        names.add(supplier.fullName);
      }
    } else {
      ids.remove(supplier.id);
      names.removeWhere(
        (n) => n.trim().toLowerCase() == supplier.fullName.trim().toLowerCase(),
      );
    }
    widget.onChanged(SupplierTargetSelection(ids: ids, names: names));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directoryAsync = ref.watch(supplierDirectoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'יעד ספקים',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'חפש לפי שם חברה. ללא בחירה — הבקשה תוצג לכל הספקים הרלוונטיים.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'חיפוש ספק לפי שם או עיר',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        directoryAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => Text(
            'לא ניתן לטעון רשימת ספקים',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
          data: (suppliers) {
            final filtered =
                SupplierDirectoryService.filterByQuery(suppliers, _query);
            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  _query.isEmpty
                      ? 'לא נמצאו ספקים במערכת'
                      : 'לא נמצא ספק התואם ל«$_query»',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final supplier in filtered)
                  FilterChip(
                    label: Text(supplier.fullName),
                    selected: _isSelected(supplier),
                    onSelected: (checked) => _toggle(supplier, checked),
                  ),
              ],
            );
          },
        ),
        if (widget.selectedNames.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25)),
            ),
            child: Text(
              'נבחרו: ${widget.selectedNames.join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (SupplierTargetingHelpers.qaSupplierPresets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'QA: ${SupplierTargetingHelpers.qaSupplierPresets.join(' · ')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
