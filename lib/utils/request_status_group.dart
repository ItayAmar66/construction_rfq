import '../models/quote_status.dart';

/// Coarse presentation buckets used to build list filter tabs.
///
/// This is purely a *view* grouping over the canonical [QuoteRequestStatus] —
/// it changes nothing about the underlying status, workflow, or permissions.
enum RequestStatusGroup {
  /// Not yet submitted / bounced back for edits.
  drafts,

  /// Live in the RFQ/quoting flow, awaiting action.
  open,

  /// Ordered and moving through fulfilment.
  inProgress,

  /// Terminal — received, completed, closed or cancelled.
  done,
}

/// Maps a canonical [QuoteRequestStatus] to its coarse [RequestStatusGroup].
///
/// Exhaustive over the enum (the compiler enforces every case), so adding a
/// new status forces an explicit bucketing decision here.
RequestStatusGroup requestStatusGroup(QuoteRequestStatus status) {
  switch (status) {
    case QuoteRequestStatus.draft:
    case QuoteRequestStatus.procurementRejected:
      return RequestStatusGroup.drafts;
    case QuoteRequestStatus.pendingApproval:
    case QuoteRequestStatus.procurementApproved:
    case QuoteRequestStatus.sent:
    case QuoteRequestStatus.quotesReceived:
      return RequestStatusGroup.open;
    case QuoteRequestStatus.ordered:
    case QuoteRequestStatus.shipped:
    case QuoteRequestStatus.pendingReceipt:
      return RequestStatusGroup.inProgress;
    case QuoteRequestStatus.receivedFull:
    case QuoteRequestStatus.receivedWithIssues:
    case QuoteRequestStatus.completed:
    case QuoteRequestStatus.closed:
    case QuoteRequestStatus.cancelled:
      return RequestStatusGroup.done;
  }
}
