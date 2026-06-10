import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/widgets/app_shell.dart';
import 'package:construction_rfq/widgets/content_max_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ContentMaxWidth expands on desktop widths', () {
    const widget = ContentMaxWidth(child: SizedBox());
    expect(widget.expandsOnWidth(1400), isTrue);
    expect(widget.expandsOnWidth(900), isTrue);
    expect(widget.expandsOnWidth(899), isFalse);
  });

  testWidgets('desktop shell content uses wide area not 1100 cap', (tester) async {
    double? childMaxWidth;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1440, 900));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentMaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                childMaxWidth = constraints.maxWidth;
                return const SizedBox(height: 80);
              },
            ),
          ),
        ),
      ),
    );

    expect(childMaxWidth, isNotNull);
    expect(childMaxWidth!, greaterThan(1100));
    expect(
      childMaxWidth!,
      closeTo(1440 - ContentMaxWidth.defaultDesktopHorizontalPadding * 2, 1),
    );
  });

  testWidgets('mobile shell keeps narrow layout behavior', (tester) async {
    double? childMaxWidth;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentMaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                childMaxWidth = constraints.maxWidth;
                return const SizedBox(height: 80);
              },
            ),
          ),
        ),
      ),
    );

    expect(childMaxWidth, closeTo(390, 1));
  });

  testWidgets('AppShell desktop shows rail and wide content', (tester) async {
    double? childMaxWidth;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1440, 900));

    final user = AppUser(
      id: 'u1',
      fullName: 'Test',
      email: 't@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'TLV',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => AsyncValue.data(user)),
        ],
        child: MaterialApp(
          home: AppShell(
            currentPath: '/home',
            child: LayoutBuilder(
              builder: (context, constraints) {
                childMaxWidth = constraints.maxWidth;
                return const SizedBox(height: 80);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(childMaxWidth, isNotNull);
    expect(childMaxWidth!, greaterThan(1100));
  });
}
