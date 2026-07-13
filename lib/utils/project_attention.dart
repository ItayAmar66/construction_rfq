import 'package:flutter/material.dart';

import '../models/quote_request.dart';
import '../models/quote_status.dart';

/// A single "requires attention" row derivable from a project's RFQs.
/// Shared between contractor and supplier project workspaces so the
/// attention heuristics stay consistent across both sides.
class ProjectAttentionItem {
  const ProjectAttentionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.requestId,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final String requestId;
}

/// Builds contractor-facing attention rows: new quotes to review, RFQs with
/// no supplier response yet, and shipments in-flight or reported with issues.
List<ProjectAttentionItem> buildContractorAttentionItems(
  List<QuoteRequest> requests,
  Color amber,
  Color danger,
  Color navy,
) {
  final items = <ProjectAttentionItem>[];
  for (final r in requests) {
    switch (r.status) {
      case QuoteRequestStatus.quotesReceived:
        items.add(ProjectAttentionItem(
          icon: Icons.mark_email_read_outlined,
          title: 'התקבלו הצעות חדשות',
          subtitle: r.projectName ?? r.customerName,
          tone: amber,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.sent:
        items.add(ProjectAttentionItem(
          icon: Icons.hourglass_empty_outlined,
          title: 'בקשה ללא מענה ספקים',
          subtitle: r.projectName ?? r.customerName,
          tone: navy,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.shipped:
        items.add(ProjectAttentionItem(
          icon: Icons.local_shipping_outlined,
          title: 'משלוח בדרך',
          subtitle: r.projectName ?? r.customerName,
          tone: navy,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.receivedWithIssues:
        items.add(ProjectAttentionItem(
          icon: Icons.report_problem_outlined,
          title: 'התקבל עם חריגות',
          subtitle: r.projectName ?? r.customerName,
          tone: danger,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.pendingApproval:
        items.add(ProjectAttentionItem(
          icon: Icons.pending_actions_outlined,
          title: 'ממתין לאישור רכש',
          subtitle: r.projectName ?? r.customerName,
          tone: amber,
          requestId: r.id,
        ));
        break;
      default:
        break;
    }
  }
  return items;
}

/// Builds supplier-facing attention rows for a set of RFQs the supplier can see:
/// brand-new RFQs awaiting a quote, and orders that need shipping soon.
List<ProjectAttentionItem> buildSupplierAttentionItems(
  List<QuoteRequest> requests,
  Color amber,
  Color danger,
  Color navy,
) {
  final items = <ProjectAttentionItem>[];
  for (final r in requests) {
    switch (r.status) {
      case QuoteRequestStatus.sent:
        items.add(ProjectAttentionItem(
          icon: Icons.new_releases_outlined,
          title: 'בקשת מחיר חדשה — טרם הוגשה הצעה',
          subtitle: r.projectName ?? r.customerName,
          tone: amber,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.ordered:
        items.add(ProjectAttentionItem(
          icon: Icons.local_shipping_outlined,
          title: 'הזמנה ממתינה למשלוח',
          subtitle: r.projectName ?? r.customerName,
          tone: navy,
          requestId: r.id,
        ));
        break;
      case QuoteRequestStatus.receivedWithIssues:
        items.add(ProjectAttentionItem(
          icon: Icons.report_problem_outlined,
          title: 'הלקוח דיווח על חריגות במשלוח',
          subtitle: r.projectName ?? r.customerName,
          tone: danger,
          requestId: r.id,
        ));
        break;
      default:
        break;
    }
  }
  return items;
}
