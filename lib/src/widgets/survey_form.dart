import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../survey_schema.dart';
import '../theme.dart';

class SurveyFieldList extends StatelessWidget {
  const SurveyFieldList({
    super.key,
    required this.fields,
    required this.data,
    required this.onChanged,
    this.path = 'survey',
  });

  final List<SurveyField> fields;
  final Map<String, dynamic> data;
  final void Function(String key, Object? value) onChanged;
  final String path;

  @override
  Widget build(BuildContext context) {
    final visibleFields = fields
        .where((field) => field.visibleWhen?.matches(data) ?? true)
        .toList();

    if (visibleFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visibleFields.length; index++) ...[
          _SurveyFieldInput(
            key: ValueKey('$path.${visibleFields[index].key}'),
            field: visibleFields[index],
            data: data,
            onChanged: onChanged,
            path: '$path.${visibleFields[index].key}',
          ),
          if (index != visibleFields.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SurveyFieldInput extends StatelessWidget {
  const _SurveyFieldInput({
    super.key,
    required this.field,
    required this.data,
    required this.onChanged,
    required this.path,
  });

  final SurveyField field;
  final Map<String, dynamic> data;
  final void Function(String key, Object? value) onChanged;
  final String path;

  @override
  Widget build(BuildContext context) {
    final value = data[field.key];

    return switch (field.type) {
      SurveyFieldType.text => _SurveyTextField(
        value: _stringValue(value),
        label: field.label,
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.number => _SurveyTextField(
        value: _stringValue(value),
        label: field.label,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.date => _SurveyTextField(
        value: _stringValue(value),
        label: field.label,
        readOnly: true,
        suffixIcon: Icons.calendar_month_outlined,
        onTap: () => _pickDate(context, _stringValue(value)),
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.time => _SurveyTextField(
        value: _stringValue(value),
        label: field.label,
        readOnly: true,
        suffixIcon: Icons.schedule_outlined,
        onTap: () => _pickTime(context, _stringValue(value)),
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.textarea => _SurveyTextField(
        value: _stringValue(value),
        label: field.label,
        minLines: 3,
        maxLines: 5,
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.select => _SurveySelectField(
        label: field.label,
        value: _stringValue(value),
        options: field.options,
        onChanged: (nextValue) => onChanged(field.key, nextValue),
        path: path,
      ),
      SurveyFieldType.multiSelect => _SurveyMultiSelectField(
        label: field.label,
        path: path,
        values: _stringSet(value),
        options: field.options,
        onChanged: (nextValue) =>
            onChanged(field.key, nextValue.toList()..sort()),
      ),
      SurveyFieldType.boolean => _SurveyCheckboxField(
        label: field.label,
        value: value == true,
        onChanged: (nextValue) => onChanged(field.key, nextValue),
      ),
      SurveyFieldType.repeatableTable =>
        field.key == 'income_earners'
            ? _SurveyIncomeEarnersField(
                field: field,
                rows: normalizedIncomeEarnerRows(value),
                familyRows: surveyMapRows(data['family_members']),
                onChanged: (rows) {
                  onChanged(field.key, rows);
                  onChanged(
                    'income_earner_count',
                    incomeEarnerCountFromRows(rows),
                  );
                },
              )
            : _SurveyRepeatableTable(
                field: field,
                rows: _rowList(value),
                onChanged: (rows) => onChanged(field.key, rows),
                path: path,
              ),
      SurveyFieldType.note => _SurveyNote(field: field),
      SurveyFieldType.heading => _SurveyHeading(label: field.label),
    };
  }

  Future<void> _pickDate(BuildContext context, String currentValue) async {
    final initialDate = DateTime.tryParse(currentValue) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    onChanged(field.key, DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickTime(BuildContext context, String currentValue) async {
    final initialTime = _parseTimeOfDay(currentValue) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) {
      return;
    }
    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    onChanged(field.key, '$hour:$minute');
  }
}

class _SurveyTextField extends StatefulWidget {
  const _SurveyTextField({
    required this.value,
    required this.label,
    required this.onChanged,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final bool readOnly;
  final IconData? suffixIcon;
  final VoidCallback? onTap;

  @override
  State<_SurveyTextField> createState() => _SurveyTextFieldState();
}

class _SurveyTextFieldState extends State<_SurveyTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SurveyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.value == _controller.text) {
          return;
        }
        _controller.text = widget.value;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useExternalLabel = _usesExternalSurveyLabel(widget.label);

    return _SurveyLabeledControl(
      label: widget.label,
      useExternalLabel: useExternalLabel,
      child: TextFormField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        onChanged: widget.onChanged,
        decoration: _surveyInputDecoration(
          widget.label,
          alignLabelWithHint: (widget.minLines ?? 1) > 1,
          suffixIcon: widget.suffixIcon == null
              ? null
              : Icon(widget.suffixIcon),
          useExternalLabel: useExternalLabel,
          hintText: widget.readOnly ? 'Select' : 'Enter response',
        ),
      ),
    );
  }
}

class _SurveySelectField extends StatelessWidget {
  const _SurveySelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.path,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String path;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.trim();
    final currentValue = options.contains(normalizedValue)
        ? normalizedValue
        : null;
    final useExternalLabel = _usesExternalSurveyLabel(label);

    return _SurveyLabeledControl(
      label: label,
      useExternalLabel: useExternalLabel,
      child: DropdownButtonFormField<String>(
        key: ValueKey('select.$path.$currentValue'),
        initialValue: currentValue,
        isExpanded: true,
        decoration: _surveyInputDecoration(
          label,
          useExternalLabel: useExternalLabel,
        ),
        hint: useExternalLabel ? const Text('Select one') : null,
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (nextValue) {
          if (nextValue != null) {
            onChanged(nextValue);
          }
        },
      ),
    );
  }
}

class _SurveyMultiSelectField extends StatelessWidget {
  const _SurveyMultiSelectField({
    required this.label,
    required this.path,
    required this.values,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String path;
  final Set<String> values;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedText = values.isEmpty ? 'None selected' : values.join(', ');
    final selectedStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: values.isEmpty ? KasudloColors.muted : KasudloColors.text,
    );
    final useExternalLabel = _usesExternalSurveyLabel(label);

    return _SurveyLabeledControl(
      label: label,
      useExternalLabel: useExternalLabel,
      child: InkWell(
        key: ValueKey('multi.$path'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showChecklist(context),
        child: InputDecorator(
          decoration: _surveyInputDecoration(
            label,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            useExternalLabel: useExternalLabel,
          ),
          isEmpty: values.isEmpty,
          child: Text(
            selectedText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: selectedStyle,
          ),
        ),
      ),
    );
  }

  Future<void> _showChecklist(BuildContext context) async {
    final nextValues = values.toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: nextValues.isEmpty
                                ? null
                                : () {
                                    setSheetState(nextValues.clear);
                                    onChanged(nextValues);
                                  },
                            child: const Text('Clear'),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            CheckboxListTile(
                              value: nextValues.contains(option),
                              title: Text(option),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (selected) {
                                setSheetState(() {
                                  if (selected ?? false) {
                                    nextValues.add(option);
                                  } else {
                                    nextValues.remove(option);
                                  }
                                });
                                onChanged(nextValues);
                              },
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SurveyCheckboxField extends StatelessWidget {
  const _SurveyCheckboxField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurveyRowContainer(
      padding: EdgeInsets.zero,
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        onChanged: (nextValue) => onChanged(nextValue ?? false),
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SurveyLabeledControl extends StatelessWidget {
  const _SurveyLabeledControl({
    required this.label,
    required this.useExternalLabel,
    required this.child,
  });

  final String label;
  final bool useExternalLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useExternalLabel) {
      return child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: KasudloColors.muted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SurveyRowContainer extends StatelessWidget {
  const _SurveyRowContainer({
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: KasudloColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SurveyIncomeEarnersField extends StatelessWidget {
  const _SurveyIncomeEarnersField({
    required this.field,
    required this.rows,
    required this.familyRows,
    required this.onChanged,
  });

  final SurveyField field;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> familyRows;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxRows = field.maxRows;
    final canAdd = maxRows == null || rows.length < maxRows;
    final count = incomeEarnerCountFromRows(rows);
    final memberChoices = _incomeEarnerMemberChoices(familyRows);

    return Column(
      key: const ValueKey('income_earners_editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                field.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Text(
              '$count${maxRows == null ? '' : '/$maxRows'}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select from the family members already entered.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'No income earners added yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          ),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _IncomeEarnerRowEditor(
            index: index,
            row: rows[index],
            memberChoices: memberChoices,
            onChanged: (row) => _updateRow(index, row),
            onRemove: () => _removeRow(index),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canAdd ? _addRow : null,
          icon: const Icon(Icons.add),
          label: Text(field.addButtonLabel ?? 'Add Income Earner'),
        ),
      ],
    );
  }

  void _addRow() {
    onChanged(normalizedIncomeEarnerRows([...rows, <String, dynamic>{}]));
  }

  void _removeRow(int index) {
    final nextRows = [
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
        if (rowIndex != index) Map<String, dynamic>.from(rows[rowIndex]),
    ];
    onChanged(normalizedIncomeEarnerRows(nextRows));
  }

  void _updateRow(int index, Map<String, dynamic> row) {
    final nextRows = [for (final item in rows) Map<String, dynamic>.from(item)];
    nextRows[index] = row;
    onChanged(normalizedIncomeEarnerRows(nextRows));
  }
}

class _IncomeEarnerRowEditor extends StatelessWidget {
  const _IncomeEarnerRowEditor({
    required this.index,
    required this.row,
    required this.memberChoices,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final Map<String, dynamic> row;
  final List<_IncomeEarnerMemberChoice> memberChoices;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedMemberNo = _stringValue(row['family_member_no']);
    final currentMemberNo =
        memberChoices.any((choice) => choice.memberNo == selectedMemberNo)
        ? selectedMemberNo
        : null;

    return _SurveyRowContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Earner ${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove income earner',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('income_earner_member_$index.$currentMemberNo'),
              initialValue: currentMemberNo,
              isExpanded: true,
              decoration: _surveyInputDecoration('Income earner'),
              items: [
                for (final choice in memberChoices)
                  DropdownMenuItem(
                    value: choice.memberNo,
                    child: Text(choice.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: memberChoices.isEmpty
                  ? null
                  : (memberNo) {
                      if (memberNo == null) {
                        return;
                      }
                      final choice = memberChoices.firstWhere(
                        (item) => item.memberNo == memberNo,
                      );
                      onChanged({
                        ...row,
                        'family_member_no': choice.memberNo,
                        'family_member_name': choice.name,
                        'family_position': choice.relationship,
                      });
                    },
            ),
            const SizedBox(height: 12),
            _SurveyTextField(
              value: _stringValue(row['family_position']),
              label: 'Family position',
              onChanged: (value) =>
                  onChanged({...row, 'family_position': value}),
            ),
            const SizedBox(height: 12),
            _SurveyTextField(
              value: _stringValue(row['income_php']),
              label: 'Income PHP',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => onChanged({...row, 'income_php': value}),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyRepeatableTable extends StatelessWidget {
  const _SurveyRepeatableTable({
    required this.field,
    required this.rows,
    required this.onChanged,
    required this.path,
  });

  final SurveyField field;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final String path;

  @override
  Widget build(BuildContext context) {
    final maxRows = field.maxRows;
    final canAdd = maxRows == null || rows.length < maxRows;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(field.label, style: labelStyle)),
            if (maxRows != null)
              Text(
                '${rows.length}/$maxRows',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'No rows added yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          ),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _SurveyRowContainer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Row ${index + 1}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove row',
                        onPressed: () => _removeRow(index),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SurveyFieldList(
                    fields: field.fields,
                    data: rows[index],
                    onChanged: (key, value) => _updateRow(index, key, value),
                    path: '$path.$index',
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canAdd ? _addRow : null,
          icon: const Icon(Icons.add),
          label: Text(field.addButtonLabel ?? 'Add Row'),
        ),
      ],
    );
  }

  void _addRow() {
    final rowNumber = rows.length + 1;
    final nextRow = <String, dynamic>{};
    for (final childField in field.fields) {
      if (_isNumberingField(childField.key)) {
        nextRow[childField.key] = rowNumber;
      }
    }
    onChanged([...rows, nextRow]);
  }

  void _removeRow(int index) {
    final nextRows = [
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
        if (rowIndex != index) Map<String, dynamic>.from(rows[rowIndex]),
    ];
    onChanged(nextRows);
  }

  void _updateRow(int index, String key, Object? value) {
    final nextRows = [for (final row in rows) Map<String, dynamic>.from(row)];
    nextRows[index][key] = value;
    if (field.key == 'anthropometric_data_under_5' &&
        (key == 'weight_kg' || key == 'height_m')) {
      _updateCalculatedBmi(nextRows[index]);
    }
    onChanged(nextRows);
  }
}

void _updateCalculatedBmi(Map<String, dynamic> row) {
  final weightKg = _parseDecimal(row['weight_kg']);
  final heightM = _parseDecimal(row['height_m']);
  if (weightKg == null || heightM == null || heightM <= 0) {
    row.remove('bmi');
    return;
  }

  row['bmi'] = _formatCalculatedNumber(weightKg / (heightM * heightM));
}

class _SurveyNote extends StatelessWidget {
  const _SurveyNote({required this.field});

  final SurveyField field;

  @override
  Widget build(BuildContext context) {
    final description = field.description;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurveyHeading extends StatelessWidget {
  const _SurveyHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IncomeEarnerMemberChoice {
  const _IncomeEarnerMemberChoice({
    required this.memberNo,
    required this.name,
    required this.relationship,
  });

  final String memberNo;
  final String name;
  final String relationship;

  String get label {
    final displayName = name.isEmpty ? 'Member $memberNo' : name;
    if (relationship.isEmpty) {
      return '$memberNo - $displayName';
    }
    return '$memberNo - $displayName ($relationship)';
  }
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value';
}

InputDecoration _surveyInputDecoration(
  String label, {
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
  bool useExternalLabel = false,
  String? hintText,
}) {
  return InputDecoration(
    labelText: useExternalLabel ? null : label,
    hintText: useExternalLabel ? hintText : null,
    alignLabelWithHint: alignLabelWithHint,
    suffixIcon: suffixIcon,
  );
}

bool _usesExternalSurveyLabel(String label) => label.trim().length > 22;

double? _parseDecimal(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  final text = _stringValue(value).trim().replaceAll(',', '');
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text);
}

String _formatCalculatedNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  if (!fixed.contains('.')) {
    return fixed;
  }
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

Set<String> _stringSet(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toSet();
  }
  final text = _stringValue(value);
  return text.isEmpty ? <String>{} : {text};
}

List<Map<String, dynamic>> _rowList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

bool _isNumberingField(String key) =>
    key == 'member_no' || key == 'earner_no' || key.endsWith('_no');

List<_IncomeEarnerMemberChoice> _incomeEarnerMemberChoices(
  List<Map<String, dynamic>> rows,
) {
  return [
    for (var index = 0; index < rows.length; index++)
      _IncomeEarnerMemberChoice(
        memberNo: _stringValue(rows[index]['member_no']).trim().isEmpty
            ? '${index + 1}'
            : _stringValue(rows[index]['member_no']).trim(),
        name: _stringValue(rows[index]['name_of_family_member']).trim(),
        relationship: _stringValue(rows[index]['relationship_to_head']).trim(),
      ),
  ];
}

TimeOfDay? _parseTimeOfDay(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}
