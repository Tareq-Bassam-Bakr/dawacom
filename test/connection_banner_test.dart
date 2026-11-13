import 'dart:async';

import 'package:dawacom/widgets/connection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<bool> status;

  Future<void> pumpBanner(WidgetTester tester) async {
    status = StreamController<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionBanner(
          online: status.stream,
          child: const Scaffold(body: Text('content')),
        ),
      ),
    );
  }

  testWidgets('no banner while connected', (tester) async {
    await pumpBanner(tester);
    status.add(true);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(ConnectionBanner.offlineText), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('short cache-only moment at startup does not flash', (
    tester,
  ) async {
    await pumpBanner(tester);
    status.add(false);
    await tester.pump(const Duration(seconds: 1));
    status.add(true);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(ConnectionBanner.offlineText), findsNothing);
    expect(find.text(ConnectionBanner.restoredText), findsNothing);
  });

  testWidgets('shows offline banner, then a brief restored message', (
    tester,
  ) async {
    await pumpBanner(tester);
    status.add(false);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(ConnectionBanner.offlineText), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(ConnectionBanner.offlineText), findsOneWidget);
    expect(find.text('content'), findsOneWidget);

    status.add(true);
    // الحدث يصل أولاً، ثم يُرسم التغيير في الإطار التالي.
    await tester.pump();
    await tester.pump();
    expect(find.text(ConnectionBanner.offlineText), findsNothing);
    expect(find.text(ConnectionBanner.restoredText), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(ConnectionBanner.restoredText), findsNothing);
  });
}
