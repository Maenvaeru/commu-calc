import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:commu_calc/main.dart';

void main() {
  testWidgets('CommuCalcApp smoke test and UI verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CommuCalcApp());
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Commu-Calc'), findsOneWidget);
    expect(find.text('Свет (День)'), findsOneWidget);
    expect(find.text('Свет (Ночь)'), findsOneWidget);
    expect(find.text('Отопление'), findsOneWidget);
    expect(find.text('Вода ГВС'), findsOneWidget);
    expect(find.text('Вода ХВС'), findsOneWidget);
    expect(find.text('СОХРАНИТЬ ПОКАЗАНИЯ'), findsOneWidget);
  });
}
