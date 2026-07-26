import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/app_analytics.dart';
import '../../analytics/catalog_rfq_analytics.dart';
import '../../models/request_type.dart';
import '../../providers/cart_provider.dart';
import '../../models/enterprise/project.dart';
import '../../models/quote_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../providers/shared_preferences_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/design_system/design_system.dart';
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
  bool _lastSubmitFailed = false;
  RequestType _requestType = RequestType.regular;
  Duration _tenderDuration = const Duration(hours: 24);
  List<String> _targetSupplierIds = const [];
  List<String> _targetSupplierNames = const [];
  List<String> _targetSupplierOrgIds = const [];
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
      _attachDraftScope();
    });
  }

  Future<void> _attachDraftScope() async {
    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    final orgId = ref.read(primaryOrgIdProvider);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!mounted) return;
    ref.read(rfqDraftProvider.notifier).attachScope(
          prefs: prefs,
          uid: uid,
          orgId: orgId,
        );
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

  void _maybeTrackDraftStarted() {
    if (ref.read(rfqDraftProvider).isEmpty) {
      ref.read(appAnalyticsProvider).track(AppAnalyticsEvents.rfqDraftStarted);
    }
  }

  Future<void> _pickFromCatalog() async {
    final draft = await CatalogSelectorSheet.show(context);
    if (draft == null || !mounted) return;

    ref.read(catalogRfqAnalyticsProvider).track(
      CatalogRfqEventNames.catalogItemSelected,
      {'variantId': draft.variantId, 'source': 'rfq_draft'},
    );
    _maybeTrackDraftStarted();
    ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
  }

  Future<void> _addManualItem() async {
    final result = await ManualRfqItemDialog.show(context);
    if (result != null && mounted) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.manualItemAdded,
          );
      _maybeTrackDraftStarted();
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
          TertiaryButton(
            label: HebrewStrings.no,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          PrimaryButton(
            label: HebrewStrings.yes,
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _lastSubmitFailed = false;
    });
    try {
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) throw Exception('לא מחובר');
      final canSend = ref.read(canSubmitRfqProvider);
      final orgId = ref.read(primaryOrgIdProvider);
      final submitStatus = canSend
          ? QuoteRequestStatus.sent
          : QuoteRequestStatus.pendingApproval;
      // Honor an explicit "no project" (null) selection: only resolve a project
      // when the user actually has one selected. Falling back to the route
      // project here would re-tag a request the user deliberately deselected.
      Project? selectedProject;
      if (_selectedProjectId != null) {
        if (_resolvedRouteProject?.id == _selectedProjectId) {
          selectedProject = _resolvedRouteProject;
        }
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
            invitedSupplierOrgIds: _targetSupplierOrgIds,
            submitStatus: submitStatus,
            projectId: _selectedProjectId,
            projectName: selectedProject?.name,
            projectLocation: selectedProject?.snapshotLocation,
            siteName: selectedProject?.snapshotLocation,
            contractorOrgId: contractorOrgId,
            clientOperationId: ref.read(rfqDraftProvider.notifier).clientOperationId,
          );
      if (!mounted) return;
      if (submitStatus == QuoteRequestStatus.sent) {
        ref.read(appAnalyticsProvider).track(AppAnalyticsEvents.rfqSent, {
          'request_type': _requestType.name,
          'invited_supplier_count': _targetSupplierIds.length,
          'has_project': _selectedProjectId != null,
        });
      }
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
        setState(() => _lastSubmitFailed = true);
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחיקת טיוטה'),
        content: const Text('כל הפריטים בטיוטה יימחקו. לא ניתן לשחזר.'),
        actions: [
          TertiaryButton(
            label: HebrewStrings.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          PrimaryButton.danger(
            label: 'מחק טיוטה',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(rfqDraftProvider.notifier).clear();
    ref.read(cartProvider.notifier).clear();
    setState(() => _lastSubmitFailed = false);
  }

  Widget _draftStatusBanner(bool isOnline) {
    if (_submitting) {
      return _statusChip(
        icon: Icons.send_outlined,
        label: 'שולח בקשה...',
        color: AppTheme.teal,
        showSpinner: true,
      );
    }
    if (_lastSubmitFailed) {
      return _statusChip(
        icon: Icons.error_outline,
        label: 'השליחה נכשלה — ניתן לנסות שוב',
        color: AppTheme.danger,
      );
    }
    if (!isOnline) {
      return _statusChip(
        icon: Icons.cloud_off_outlined,
        label: 'אין חיבור לאינטרנט — הטיוטה נשמרה במכשיר',
        color: AppTheme.amber,
      );
    }
    return _statusChip(
      icon: Icons.save_outlined,
      label: 'הטיוטה נשמרת אוטומטית במכשיר',
      color: AppTheme.textSecondary,
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
    bool showSpinner = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (showSpinner)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(rfqDraftProvider);
    final canSend = ref.watch(canSubmitRfqProvider);
    final canSubmit = ref.watch(canSubmitMaterialRequestProvider);
    final summary = summarizeRfqDraft(draft);
    final catalogLines = draft.where((item) => item.isCatalogMatched).toList();
    final manualLines = draft.where((item) => !item.isCatalogMatched).toList();
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    ref.listen(cartProvider, (prev, next) {
      if (next.isNotEmpty) {
        ref.read(rfqDraftProvider.notifier).importLegacyCart(next);
      }
    });

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.rfqDraftTitle,
        actions: draft.isEmpty
            ? null
            : [
                IconButton(
                  tooltip: 'מחק טיוטה',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _submitting ? null : _discardDraft,
                ),
              ],
      ),
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
                    PrimaryButton.icon(
                      icon: Icons.manage_search_outlined,
                      label: HebrewStrings.pickFromCatalog,
                      expand: false,
                      onPressed: _pickFromCatalog,
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: HebrewStrings.addManualRfqItem,
                      icon: Icons.edit_outlined,
                      onPressed: _addManualItem,
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
                            child: SecondaryButton(
                              label: HebrewStrings.pickFromCatalog,
                              icon: Icons.manage_search_outlined,
                              onPressed: _pickFromCatalog,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SecondaryButton(
                              label: HebrewStrings.addManualRfqItem,
                              icon: Icons.edit_outlined,
                              onPressed: _addManualItem,
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
                      AppTextField(
                        controller: _notesController,
                        label: HebrewStrings.notes,
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
                          selectedOrgIds: _targetSupplierOrgIds,
                          onChanged: (selection) => setState(() {
                            _targetSupplierIds = selection.ids;
                            _targetSupplierNames = selection.names;
                            _targetSupplierOrgIds = selection.orgIds;
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
                _draftStatusBanner(isOnline),
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
