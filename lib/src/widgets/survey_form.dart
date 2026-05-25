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
        values: _stringSet(value),
        options: field.options,
        onChanged: (nextValue) =>
            onChanged(field.key, nextValue.toList()..sort()),
      ),
      SurveyFieldType.boolean => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: value == true,
        onChanged: (nextValue) => onChanged(field.key, nextValue ?? false),
        title: Text(field.label),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      SurveyFieldType.repeatableTable => _SurveyRepeatableTable(
        field: field,
        rows: _rowList(value),
        onChanged: (rows) => onChanged(field.key, rows),
        path: path,
      ),
      SurveyFieldType.note => _SurveyNote(field: field),
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
    return TextFormField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        alignLabelWithHint: (widget.minLines ?? 1) > 1,
        suffixIcon: widget.suffixIcon == null ? null : Icon(widget.suffixIcon),
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

    return DropdownButtonFormField<String>(
      key: ValueKey('select.$path.$currentValue'),
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
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
    );
  }
}

class _SurveyMultiSelectField extends StatelessWidget {
  const _SurveyMultiSelectField({
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Set<String> values;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: values.contains(option),
                onSelected: (selected) {
                  final nextValues = values.toSet();
                  selected ? nextValues.add(option) : nextValues.remove(option);
                  onChanged(nextValues);
                },
              ),
          ],
        ),
      ],
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
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: KasudloColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
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
    onChanged(nextRows);
  }
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

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value';
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
