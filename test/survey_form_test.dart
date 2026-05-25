import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/survey_schema.dart';
import 'package:kasudlo/src/widgets/survey_form.dart';

void main() {
  testWidgets('anthropometric table auto-calculates BMI', (tester) async {
    final data = <String, dynamic>{};
    final anthropometricField = nutritionalStatusFields.firstWhere(
      (field) => field.key == 'anthropometric_data_under_5',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SingleChildScrollView(
                child: SurveyFieldList(
                  fields: [anthropometricField],
                  data: data,
                  onChanged: (key, value) {
                    setState(() => data[key] = value);
                  },
                  path: 'nutrition',
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Child'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Wt. in kg.'),
      '16',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ht. in m'),
      '0.8',
    );
    await tester.pumpAndSettle();

    final rows = data['anthropometric_data_under_5'] as List<dynamic>;
    expect((rows.single as Map<String, dynamic>)['bmi'], '25');
  });
}
