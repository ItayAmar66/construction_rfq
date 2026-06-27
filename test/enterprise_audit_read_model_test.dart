import 'package:construction_rfq/data/enterprise_demo_scenario.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/enterprise_audit_read_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    EnterpriseDemoScenario.seedIfNeeded(MockStore.instance);
  });

  test('builds full lifecycle audit read model', () {
    final request = MockStore.instance.getRequest(
      EnterpriseDemoScenario.fulfilledRequestId,
    )!;
    final quotes = MockStore.instance.supplierQuotes
        .where((q) => q.quoteRequestId == request.id)
        .toList();

    final model = EnterpriseAuditReadModelBuilder.build(
      request: request,
      quotes: quotes,
    );

    expect(model.requestId, EnterpriseDemoScenario.fulfilledRequestId);
    expect(model.isFulfilled, isTrue);
    expect(model.entries.length, greaterThanOrEqualTo(4));
    expect(request.status, QuoteRequestStatus.pendingReceipt);
  });
}
