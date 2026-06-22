import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/catalog_rfq_analytics.dart';
import '../../models/request_type.dart';
import '../../providers/cart_provider.dart';
import '../../models/enterprise/project.dart';
import '../../models/quote_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/manual_rfq_item_dialog.dart';
import '../../utils/rfq_draft_helpers.dart';
import '../../widgets/rfq_builder_sections.dart';
import '../../widgets/rfq_review_summary_card.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/procurement_panel.dart';
import '../../widgets/rfq_draft_submit_bar.dart';
import '../../widgets/rfq_supplier_target_picker.dart';
import '../../widgets/rfq_draft_line_card.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _notesController = TextEditingController();
  bool _submitting = false;
  RequestType _requestType = RequestType.regular;
  Duration _tenderDuration = const Duration(hours: 24);
  List<String> _targetSupplierIds = const [];
  List<String> _targetSupplierNames = const [];
  List<Project> _projects = const [];
  String? _selectedProjectId;
  Project? _resolvedRouteProject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLegacyCart();
      _initProjectFromRoute();
    });
  }

  void _initProjectFromRoute() {
    final projectId =
        GoRouterState.of(context).uri.queryParameters['projectId'];
    if (projectId != null && projectId.isNotEmpty) {
      setState(() => _selectedProjectId = projectId);
      _resolveRouteProject(projectId);
    }
  }

  Future<void> _resolveRouteProject(String projectId) async {
    final project =
        await ref.read(projectRepositoryProvider).getProject(projectId);
    if (!mounted || project == null) return;
    setState(() {
      _resolvedRouteProject = project;
      _selectedProjectId = projectId;
      if (!_projects.any((p) => p.id == project.id)) {
        _projects = [..._projects, project];
      }
    });
  }

  Future<void> _loadProjects() async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final user = session?.profile;
    if (user == null) return;
    final projects =
        await ref.read(projectRepositoryProvider).listProjectsForOwner(user.id);
    if (!mounted) return;
    final routeProjectId =
        GoRouterState.of(context).uri.queryParameters['projectId'];
    setState(() {
      _projects = projects;
      if (routeProjectId != null && routeProjectId.isNotEmpty) {
        _selectedProjectId = routeProjectId;
        if (_resolvedRouteProject?.id == routeProjectId) {
          if (!_projects.any((p) => p.id == routeProjectId)) {
            _projects = [..._projects, _resolvedRouteProject!];
          }
        }
      } else if (projects.any((p) => p.id == _selectedProjectId)) {
        // keep current selection
      }
    });
    if (routeProjectId != null &&
        routeProjectId.isNotEmpty &&
        _resolvedRouteProject?.id != routeProjectId) {
      await _resolveRouteProject(routeProjectId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_projects.isEmpty) {
      _loadProjects();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _syncLegacyCart() {
    final cart = ref.read(cartProvider);
    if (cart.isNotEmpty) {
      ref.read(rfqDraftProvider.notifier).importLegacyCart(cart);
    }
  }

  Future<void> _pickFromCatalog() async {
    final draft = await CatalogSelectorSheet.show(context);
    if (draft == null || !mounted) return;

    ref.read(catalogRfqAnalyticsProvider).track(
      CatalogRfqEventNames.catalogItemSelected,
      {'variantId': draft.variantId, 'source': 'rfq_draft'},
    );
    ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
  }

  Future<void> _addManualItem() async {
    final result = await ManualRfqItemDialog.show(context);
    if (result != null && mounted) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.manualItemAdded,
          );
      ref.read(rfqDraftProvider.notifier).addManualItem(
            productName: result.productName,
            category: result.category,
            unitType: result.unitType,
            quantity: result.quantity,
            notes: result.notes,
          );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = ref.read(rfqDraftProvider);
    if (draft.isEmpty) return;

    if (!ref.read(canSubmitMaterialRequestProvider)) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'אין הרשאה לשלוח בקשה. ממתין לאישור מנהל מערכת או הזמנה.',
        );
      }
      return;
    }

    final canSend = ref.read(canSubmitRfqProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(canSend ? HebrewStrings.confirmSubmit : 'שליחה לאישור רכש'),
        content: Text(
          canSend
              ? 'הבקשה תישלח לספקים לפי יעד הספקים שבחרת.'
              : 'הבקשה תישלח לרכש לפני שליחה לספקים.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(HebrewStrings.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(HebrewStrings.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) throw Exception('לא מחובר');
      final canSend = ref.read(canSubmitRfqProvider);
      final orgId = ref.read(primaryOrgIdProvider);
      final submitStatus = canSend
          ? QuoteRequestStatus.sent
          : QuoteRequestStatus.pendingApproval;
      Project? selectedProject = _resolvedRouteProject;
      if (_selectedProjectId != null) {
        for (final project in _projects) {
          if (project.id == _selectedProjectId) {
            selectedProject = project;
            break;
          }
        }
        selectedProject ??=
            await ref.read(projectRepositoryProvider).getProject(
                  _selectedProjectId!,
                );
      }
      final contractorOrgId = (selectedProject?.orgId?.isNotEmpty ?? false)
          ? selectedProject!.orgId
          : orgId;
      final requestId = await ref.read(quoteServiceProvider).submitQuoteRequest(
            customer: user,
            requestItems: draft,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            requestType: _requestType,
            tenderDuration: _tenderDuration,
            invitedSupplierIds: _targetSupplierIds,
            invitedSupplierNames: _targetSupplierNames,
            submitStatus: submitStatus,
            projectId: _selectedProjectId ?? selectedProject?.id,
            projectName: selectedProject?.name,
            projectLocation: selectedProject?.snapshotLocation,
            siteName: selectedProject?.snapshotLocation,
            contractorOrgId: contractorOrgId,
          );
      if (!mounted) return;
      ref.read(rfqDraftProvider.notifier).clear();
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(customerRequestsProvider);
      ref.invalidate(contractorOrgRequestsProvider);
      showAppSnackBar(
        context,
        message: canSend
            ? HebrewStrings.requestSubmitted
            : HebrewStrings.sentToProcurement,
      );
      final projectQuery = (_selectedProjectId ?? selectedProject?.id) != null
          ? '&projectId=${_selectedProjectId ?? selectedProject!.id}'
          : '';
      context.go(
        canSend
            ? '/compare-quotes/$requestId'
            : '/request-confirmation?id=$requestId&mode=procurement$projectQuery',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(rfqDraftProvider);
    final canSend = ref.watch(canSubmitRfqProvider);
    final canSubmit = ref.watch(canSubmitMaterialRequestProvider);
    final summary = summarizeRfqDraft(draft);
    final catalogLines = draft.where((item) => item.isCatalogMatched).toList();
    final manualLines = draft.where((item) => !item.isCatalogMatched).toList();

    ref.listen(cartProvider, (prev, next) {
      if (next.isNotEmpty) {
        ref.read(rfqDraftProvider.notifier).importLegacyCart(next);
      }
    });

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.rfqDraftTitle),
      body: draft.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      message: HebrewStrings.emptyRfqDraft,
                      icon: Icons.request_quote_outlined,
                      hint: HebrewStrings.emptyRfqDraftAction,
                      accentGradient: AppTheme.gradientAmber,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pickFromCatalog,
                      icon: const Icon(Icons.manage_search_outlined),
                      label: const Text(HebrewStrings.pickFromCatalog),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _addManualItem,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(HebrewStrings.addManualRfqItem),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      RfqBuilderStepHeader(
                        currentStep: summary.hasLines ? 2 : 1,
                      ),
                      const SizedBox(height: 12),
                      RfqDraftSummaryBar(summary: summary),
                      const SizedBox(height: 12),
                      if (catalogLines.isNotEmpty) ...[
                        const RfqDraftSectionHeader(
                          title: HebrewStrings.rfqCatalogSection,
                          subtitle: 'פריטים שנבחרו מהקטלוג המאושר',
                          icon: Icons.inventory_2_outlined,
                        ),
                        ...catalogLines.asMap().entries.map(
                              (entry) => RfqDraftLineCard(
                                item: entry.value,
                                lineNumber: entry.key + 1,
                                onQuantityChanged: (qty) => ref
                                    .read(rfqDraftProvider.notifier)
                                    .updateQuantity(entry.value.id, qty),
                                onNotesChanged: (notes) => ref
                                    .read(rfqDraftProvider.notifier)
                                    .updateLineNotes(entry.value.id, notes),
                                onRemove: () => ref
                                    .read(rfqDraftProvider.notifier)
                                    .removeLine(entry.value.id),
                              ),
                            ),
                      ],
                      if (manualLines.isNotEmpty) ...[
                        const RfqDraftSectionHeader(
                          title: HebrewStrings.rfqManualSection,
                          subtitle: 'פריטים חופשיים — יש לציין הערות כשצריך',
                          icon: Icons.edit_outlined,
                        ),
                        ...manualLines.asMap().entries.map(
                              (entry) => RfqDraftLineCard(
                                item: entry.value,
                                lineNumber: catalogLines.length + entry.key + 1,
                                onQuantityChanged: (qty) => ref
                                    .read(rfqDraftProvider.notifier)
                                    .updateQuantity(entry.value.id, qty),
                                onNotesChanged: (notes) => ref
                                    .read(rfqDraftProvider.notifier)
                                    .updateLineNotes(entry.value.id, notes),
                                onRemove: () => ref
                                    .read(rfqDraftProvider.notifier)
                                    .removeLine(entry.value.id),
                              ),
                            ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromCatalog,
                              icon: const Icon(Icons.manage_search_outlined),
                              label: const Text(HebrewStrings.pickFromCatalog),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addManualItem,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text(HebrewStrings.addManualRfqItem),
                            ),
                          ),
                        ],
                      ),
                      const RfqDraftSectionHeader(
                        title: HebrewStrings.rfqRequestDetailsSection,
                        icon: Icons.tune_outlined,
                      ),
                      if (_projects.isNotEmpty) ...[
                        DropdownButtonFormField<String?>(
                          value: _selectedProjectId,
                          decoration: const InputDecoration(
                            labelText: 'פרויקט / אתר',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(HebrewStrings.noProject),
                            ),
                            for (final project in _projects)
                              DropdownMenuItem<String?>(
                                value: project.id,
                                child: Text(project.displayLabel),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedProjectId = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'סוג בקשה',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RequestType>(
                        segments: [
                          ButtonSegment(
                            value: RequestType.regular,
                            label: Text(
                              RequestType.regular.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment(
                            value: RequestType.tender,
                            label: Text(RequestType.tender.label),
                          ),
                        ],
                        selected: {_requestType},
                        onSelectionChanged: (s) {
                          setState(() => _requestType = s.first);
                        },
                      ),
                      if (_requestType == RequestType.tender) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('6 שעות'),
                              selected:
                                  _tenderDuration == const Duration(hours: 6),
                              onSelected: (_) => setState(
                                () =>
                                    _tenderDuration = const Duration(hours: 6),
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('24 שעות'),
                              selected:
                                  _tenderDuration == const Duration(hours: 24),
                              onSelected: (_) => setState(
                                () =>
                                    _tenderDuration = const Duration(hours: 24),
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('3 ימים'),
                              selected:
                                  _tenderDuration == const Duration(days: 3),
                              onSelected: (_) => setState(
                                () => _tenderDuration = const Duration(days: 3),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: HebrewStrings.notes,
                        ),
                        maxLines: 2,
                      ),
                      const RfqDraftSectionHeader(
                        title: HebrewStrings.rfqReviewSection,
                        subtitle: 'בדוק שורות לפני שליחה',
                        icon: Icons.send_outlined,
                      ),
                      if (canSend) ...[
                        RfqSupplierTargetPicker(
                          selectedIds: _targetSupplierIds,
                          selectedNames: _targetSupplierNames,
                          onChanged: (selection) => setState(() {
                            _targetSupplierIds = selection.ids;
                            _targetSupplierNames = selection.names;
                          }),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        ProcurementPanel(
                          child: Text(
                            'ממתין לאישור רכש\n'
                            'הבקשה תישלח לרכש לפני שליחה לספקים',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      RfqReviewSummaryCard(
                        summary: summary,
                        items: draft,
                        invitedSupplierNames: _targetSupplierNames,
                        hasMissingNotes: summary.linesMissingNotes > 0,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                RfqDraftSubmitBar(
                  summary: summary,
                  supplierNames: canSend ? _targetSupplierNames : const [],
                  onSubmit: canSubmit ? _submit : () {},
                  submitting: _submitting,
                  canSendToSuppliers: canSend,
                ),
              ],
            ),
    );
  }
}
