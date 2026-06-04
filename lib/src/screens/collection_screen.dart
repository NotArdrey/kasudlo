import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../assessment_options.dart';
import '../models.dart';
import '../state/app_controller.dart';
import '../survey_schema.dart';
import '../theme.dart';
import '../widgets/account_request_fields.dart';
import '../widgets/ai_guidance_card.dart';
import '../widgets/app_chrome.dart';
import '../widgets/survey_form.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

enum _CollectPart {
  demographic,
  socioeconomic,
  healthIllness,
  healthResource,
  leadership,
  concerns,
}

class _CollectionScreenState extends ConsumerState<CollectionScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _familyCountController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _accountEmailController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _accountConfirmPasswordController = TextEditingController();
  final _scrollController = ScrollController();

  final _healthProblems = <String>{};
  final _communityConcerns = <String>{};
  final _surveyData = <String, dynamic>{};

  String _vaccinationStatus = 'Unknown';
  String _waterSanitation = 'Safe water and sanitary toilet';
  String _nutritionalStatus = 'Normal';
  bool _accountCreateRequested = false;
  bool _consentGiven = false;
  _CollectPart _currentPart = _CollectPart.demographic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _surveyData['family_members'] = _familyRowsForCount();
    _surveyData['time_started'] = _currentTime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_nameController.text.trim().isNotEmpty) {
        _save(submit: false, silent: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _familyCountController.dispose();
    _notesController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _accountConfirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (_nameController.text.trim().isNotEmpty) {
          _save(submit: false, silent: true);
        }
      },
      child: AppPage(
        title: 'Collect Data',
        subtitle: 'Household health assessment',
        controller: _scrollController,
        leading: BackButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              _save(submit: false, silent: true);
            }
            context.go('/home');
          },
        ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CollectPartSelector(
                currentPart: _currentPart,
                onChanged: (part) => setState(() => _currentPart = part),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_currentPart),
                  child: SurveyContext(
                    surveyData: _surveyData,
                    onGlobalChanged: _setSurveyDataValue,
                    child: _currentPartSection(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PartControls(
                currentPart: _currentPart,
                onPrevious: _goToPreviousPart,
                onNext: _goToNextPart,
              ),
              const SizedBox(height: 16),
              if (controller.errorMessage != null)
                Text(
                  controller.errorMessage!,
                  style: const TextStyle(color: KasudloColors.critical),
                ),
              if (_currentPart == _CollectPart.concerns)
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _save(submit: true),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Submit'),
                ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _currentPartSection() {
    return switch (_currentPart) {
      _CollectPart.demographic => _DemographicSection(
        nameController: _nameController,
        ageController: _ageController,
        addressController: _addressController,
        familyCountController: _familyCountController,
        familyRows: _familyRows(),
        surveyData: _surveyData,
        accountEmailController: _accountEmailController,
        accountPasswordController: _accountPasswordController,
        accountConfirmPasswordController: _accountConfirmPasswordController,
        accountCreateRequested: _accountCreateRequested,
        onSurveyChanged: _setSurveyDataValue,
        onFamilyCountChanged: _setFamilyCountValue,
        onAccountCreateRequestedChanged: (value) =>
            setState(() => _accountCreateRequested = value),
        onMemberFieldChanged: _setFamilyMemberRowValue,
        onFamilyProfileChanged: _setSurveyDataValue,
      ),
      _CollectPart.socioeconomic => _SurveyDataSection(
        title: 'II. Socio-economic, Cultural and Environmental',
        fields: [
          ...socialIndicatorFields,
          ...economicIndicatorFields,
          ...culturalIndicatorFields,
          ...environmentalIndicatorFields,
        ],
        data: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      _CollectPart.healthIllness => _ChoiceSection(
        title: 'III. Health and Illness Pattern',
        children: [
          SurveyFieldList(
            fields: [
              ...lifestylePracticeFields,
              ...nutritionalStatusFields,
              ...beliefsPracticeFields,
              ...communityHealthProgramFields,
              ...healthIndicatorFields,
            ],
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'health_illness',
          ),
        ],
      ),
      _CollectPart.healthResource => _SurveyDataSection(
        title: 'IV. Health Resource',
        fields: healthResourceFields,
        data: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      _CollectPart.leadership => _SurveyDataSection(
        title: 'V. Political/Leadership Patterns',
        fields: politicalLeadershipPatternFields,
        data: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      _CollectPart.concerns => _ConcernsSection(
        notesController: _notesController,
        communityConcerns: _communityConcerns,
        surveyData: _surveyData,
        onSurveyChanged: _setSurveyDataValue,
        onCommunityConcernChanged: _toggleCommunityConcern,
        consentGiven: _consentGiven,
        onConsentChanged: (value) => setState(() => _consentGiven = value),
      ),
    };
  }

  void _goToPreviousPart() {
    final previousIndex = _CollectPart.values.indexOf(_currentPart) - 1;
    if (previousIndex < 0) {
      return;
    }
    setState(() => _currentPart = _CollectPart.values[previousIndex]);
    _scrollToTop();
  }

  void _goToNextPart() {
    final nextIndex = _CollectPart.values.indexOf(_currentPart) + 1;
    if (nextIndex >= _CollectPart.values.length) {
      return;
    }
    setState(() => _currentPart = _CollectPart.values[nextIndex]);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleCommunityConcern(String option, bool checked) {
    setState(
      () => checked
          ? _communityConcerns.add(option)
          : _communityConcerns.remove(option),
    );
  }

  void _setSurveyDataValue(String key, Object? value) {
    setState(() {
      _surveyData[key] = value;
      if (key == 'family_members' && value is List) {
        _familyCountController.text = value.length.toString();
        _surveyData['number_of_family'] = value.length;
      }
    });
  }

  void _setFamilyCountValue(String value) {
    setState(() {
      _surveyData['number_of_family'] = int.tryParse(value.trim()) ?? value;
      _surveyData['family_members'] = _familyRowsForCount();
    });
  }

  void _setFamilyMemberRowValue(int index, String key, Object? value) {
    setState(() {
      final rows = _familyRows();
      while (rows.length <= index) {
        rows.add(<String, dynamic>{});
      }
      rows[index][key] = value;
      _surveyData['family_members'] = _renumberFamilyRows(rows);
    });
  }

  Future<void> _save({required bool submit, bool silent = false}) async {
    if (!_profileFieldsAreValid()) {
      if (!silent) {
        setState(() => _currentPart = _CollectPart.demographic);
        await Future<void>.delayed(Duration.zero);
        _formKey.currentState?.validate();
        if (!mounted) {
          return;
        }
        _showMessage('Complete community profile first.');
      }
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (submit && !_consentGiven) {
      if (!silent) {
        setState(() => _currentPart = _CollectPart.concerns);
        _showMessage('Consent is required before submitting.');
      }
      return;
    }

    if (submit) {
      _surveyData['time_finished'] = _currentTime();
    }

    final controller = ref.read(appControllerProvider);
    final surveyData = _buildSurveyData();
    final submission = _buildSubmission(controller, surveyData);
    AiHealthGuidance? guidance;

    if (submit) {
      if (!silent) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      await controller.submit(submission);
      guidance = await controller.analyzeAndSaveSubmissionGuidance(submission);
      if (mounted && !silent) {
        Navigator.of(context).pop();
      }
    } else {
      await controller.saveDraft(submission);
    }

    if (!mounted) {
      return;
    }
    if (submit) {
      if (!silent) _showMessage('Record queued for sync.');
      if (guidance != null && !silent) {
        await _showSubmittedGuidance(guidance);
        if (!mounted) {
          return;
        }
      }
      _resetForm();
      if (mounted && !silent) {
        context.go('/reports');
      }
    } else {
      if (!silent) _showMessage('Draft saved.');
    }
  }

  HealthSubmission _buildSubmission(
    AppController controller,
    Map<String, dynamic> surveyData,
  ) {
    final familyRows = _familyRowsForCount();
    final vaccinationStatus = vaccinationStatusFromSurveyData(
      surveyData,
      fallback: _vaccinationStatus,
    );

    return controller.createSubmission(
      respondentName: _nameController.text,
      respondentAge: int.tryParse(_ageController.text),
      address: _addressController.text,
      familyMembersCount: int.tryParse(_familyCountController.text) ?? 0,
      familyMembers: familyRows.map(FamilyMember.fromSurveyData).toList(),
      healthProblems: _healthProblems.toList()..sort(),
      vaccinationStatus: vaccinationStatus,
      waterSanitation: _waterSanitation,
      nutritionalStatus: _nutritionalStatus,
      communityConcerns: _communityConcerns.toList()..sort(),
      surveyData: surveyData,
      consentGiven: _consentGiven,
      notes: _notesController.text,
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _ageController.clear();
    _addressController.clear();
    _familyCountController.text = '1';
    _notesController.clear();
    _accountEmailController.clear();
    _accountPasswordController.clear();
    _accountConfirmPasswordController.clear();
    setState(() {
      _healthProblems.clear();
      _communityConcerns.clear();
      _surveyData.clear();
      _surveyData['family_members'] = _familyRowsForCount();
      _surveyData['time_started'] = _currentTime();
      _vaccinationStatus = 'Unknown';
      _waterSanitation = 'Safe water and sanitary toilet';
      _nutritionalStatus = 'Normal';
      _accountCreateRequested = false;
      _consentGiven = false;
      _currentPart = _CollectPart.demographic;
    });
  }

  bool _profileFieldsAreValid() {
    final familyCount = int.tryParse(_familyCountController.text);
    return _nameController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty &&
        familyCount != null &&
        familyCount >= 1;
  }

  Map<String, dynamic> _buildSurveyData() {
    final surveyData = Map<String, dynamic>.from(_surveyData);
    final familyRows = _familyRowsForCount();
    final healthProblems = _healthProblems.toList()..sort();
    final communityConcerns = _communityConcerns.toList()..sort();

    surveyData['informant'] = _nameController.text.trim();
    surveyData['address'] = _addressController.text.trim();
    surveyData['number_of_family'] =
        int.tryParse(_familyCountController.text.trim()) ??
        _familyCountController.text.trim();
    surveyData['family_members'] = familyRows;
    final incomeEarners = normalizedIncomeEarnerRows(
      surveyData['income_earners'],
      keepBlankRows: false,
    );
    final incomeEarnerCount = incomeEarnerCountFromRows(incomeEarners);
    surveyData['income_earners'] = incomeEarners;
    if (incomeEarnerCount > 0) {
      surveyData['income_earner_count'] = incomeEarnerCount;
    } else {
      surveyData.remove('income_earner_count');
    }
    surveyData['health_problems'] = healthProblems;
    surveyData['vaccination_status'] = vaccinationStatusFromSurveyData(
      surveyData,
      fallback: _vaccinationStatus,
    );
    surveyData['water_sanitation'] = _waterSanitation;
    surveyData['nutritional_status'] = _nutritionalStatus;
    surveyData['community_concerns'] = communityConcerns;
    surveyData['notes'] = _notesController.text.trim();
    surveyData[accountCreateRequestedKey] = _accountCreateRequested;
    surveyData[accountEmailKey] = _accountCreateRequested
        ? _accountEmailController.text.trim()
        : '';

    return _compactSurveyData(surveyData);
  }

  int? _familyCount() {
    final count = int.tryParse(_familyCountController.text.trim());
    return count == null || count < 1 ? null : count;
  }

  List<Map<String, dynamic>> _familyRowsForCount() {
    final count = _familyCount();
    final rows = _familyRows();
    if (count == null) {
      return _renumberFamilyRows(rows);
    }

    final nextRows = <Map<String, dynamic>>[];
    for (var index = 0; index < count; index++) {
      nextRows.add(
        index < rows.length
            ? Map<String, dynamic>.from(rows[index])
            : <String, dynamic>{},
      );
    }
    return _renumberFamilyRows(nextRows);
  }

  List<Map<String, dynamic>> _renumberFamilyRows(
    List<Map<String, dynamic>> rows,
  ) {
    return [
      for (var index = 0; index < rows.length; index++)
        {...rows[index], 'member_no': index + 1},
    ];
  }

  String _currentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<Map<String, dynamic>> _familyRows() {
    final value = _surveyData['family_members'];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return const [];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSubmittedGuidance(AiHealthGuidance guidance) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              maxWidth: 560,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AiGuidanceCard(guidance: guidance, isLoading: false),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CollectPartSelector extends StatelessWidget {
  const _CollectPartSelector({
    required this.currentPart,
    required this.onChanged,
  });

  final _CollectPart currentPart;
  final ValueChanged<_CollectPart> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_CollectPart>(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        showSelectedIcon: false,
        selected: {currentPart},
        onSelectionChanged: (selected) => onChanged(selected.single),
        segments: [
          for (final part in _CollectPart.values)
            ButtonSegment(value: part, label: Text(_partLabel(part))),
        ],
      ),
    );
  }
}

class _PartControls extends StatelessWidget {
  const _PartControls({
    required this.currentPart,
    required this.onPrevious,
    required this.onNext,
  });

  final _CollectPart currentPart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final firstPart = currentPart == _CollectPart.values.first;
    final lastPart = currentPart == _CollectPart.values.last;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: firstPart ? null : onPrevious,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: lastPart ? null : onNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ),
      ],
    );
  }
}

String _partLabel(_CollectPart part) => switch (part) {
  _CollectPart.demographic => 'I. Demographic',
  _CollectPart.socioeconomic => 'II. Socio-economic',
  _CollectPart.healthIllness => 'III. Health & Illness',
  _CollectPart.healthResource => 'IV. Health Resource',
  _CollectPart.leadership => 'V. Leadership',
  _CollectPart.concerns => 'VI. Concerns',
};

class _DemographicSection extends StatelessWidget {
  const _DemographicSection({
    required this.nameController,
    required this.ageController,
    required this.addressController,
    required this.familyCountController,
    required this.familyRows,
    required this.surveyData,
    required this.accountEmailController,
    required this.accountPasswordController,
    required this.accountConfirmPasswordController,
    required this.accountCreateRequested,
    required this.onSurveyChanged,
    required this.onFamilyCountChanged,
    required this.onAccountCreateRequestedChanged,
    required this.onMemberFieldChanged,
    required this.onFamilyProfileChanged,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController addressController;
  final TextEditingController familyCountController;
  final List<Map<String, dynamic>> familyRows;
  final Map<String, dynamic> surveyData;
  final TextEditingController accountEmailController;
  final TextEditingController accountPasswordController;
  final TextEditingController accountConfirmPasswordController;
  final bool accountCreateRequested;
  final void Function(String key, Object? value) onSurveyChanged;
  final ValueChanged<String> onFamilyCountChanged;
  final ValueChanged<bool> onAccountCreateRequestedChanged;
  final void Function(int index, String key, Object? value)
  onMemberFieldChanged;
  final void Function(String key, Object? value) onFamilyProfileChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'I. Demographic Variable',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _PersonalInfoSection(
          nameController: nameController,
          ageController: ageController,
          addressController: addressController,
          familyCountController: familyCountController,
          surveyData: surveyData,
          onSurveyChanged: onSurveyChanged,
          onFamilyCountChanged: onFamilyCountChanged,
        ),
        const SizedBox(height: 16),
        _ChoiceSection(
          title: 'Account',
          children: [
            AccountRequestFields(
              createRequested: accountCreateRequested,
              onCreateRequestedChanged: onAccountCreateRequestedChanged,
              emailController: accountEmailController,
              passwordController: accountPasswordController,
              confirmPasswordController: accountConfirmPasswordController,
              requirePassword: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FamilySection(
          familyRows: familyRows,
          surveyData: surveyData,
          onMemberFieldChanged: onMemberFieldChanged,
          onFamilyProfileChanged: onFamilyProfileChanged,
        ),
      ],
    );
  }
}

class _SurveyDataSection extends StatelessWidget {
  const _SurveyDataSection({
    required this.title,
    required this.fields,
    required this.data,
    required this.onChanged,
  });

  final String title;
  final List<SurveyField> fields;
  final Map<String, dynamic> data;
  final void Function(String key, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection(
      title: title,
      children: [
        SurveyFieldList(
          fields: fields,
          data: data,
          onChanged: onChanged,
          path: title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        ),
      ],
    );
  }
}

class _ConcernsSection extends StatelessWidget {
  const _ConcernsSection({
    required this.notesController,
    required this.communityConcerns,
    required this.surveyData,
    required this.onSurveyChanged,
    required this.onCommunityConcernChanged,
    required this.consentGiven,
    required this.onConsentChanged,
  });

  final TextEditingController notesController;
  final Set<String> communityConcerns;
  final Map<String, dynamic> surveyData;
  final void Function(String key, Object? value) onSurveyChanged;
  final void Function(String option, bool checked) onCommunityConcernChanged;
  final bool consentGiven;
  final ValueChanged<bool> onConsentChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection(
      title:
          'VI. Any Concerns/Suggestions Regarding Lifestyle in the Area in General',
      children: [
        SurveyFieldList(
          fields: lifestyleConcernSuggestionFields,
          data: surveyData,
          onChanged: onSurveyChanged,
          path: 'concerns_suggestions',
        ),
        _CheckboxGroup(
          title: 'Community concerns',
          options: communityConcernOptions,
          selected: communityConcerns,
          onChanged: onCommunityConcernChanged,
        ),
        TextFormField(
          controller: notesController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consentGiven,
          onChanged: (value) => onConsentChanged(value ?? false),
          title: const Text('Consent was given'),
          subtitle: const Text(
            'Information is collected for healthcare purposes.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

class _PersonalInfoSection extends StatelessWidget {
  const _PersonalInfoSection({
    required this.nameController,
    required this.ageController,
    required this.addressController,
    required this.familyCountController,
    required this.surveyData,
    required this.onSurveyChanged,
    required this.onFamilyCountChanged,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController addressController;
  final TextEditingController familyCountController;
  final Map<String, dynamic> surveyData;
  final void Function(String key, Object? value) onSurveyChanged;
  final ValueChanged<String> onFamilyCountChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection(
      title: 'Community profile',
      children: [
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Informant',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter informant' : null,
        ),
        TextFormField(
          controller: ageController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Age',
            prefixIcon: Icon(Icons.cake_outlined),
          ),
        ),
        TextFormField(
          controller: addressController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter address' : null,
        ),
        TextFormField(
          controller: familyCountController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: onFamilyCountChanged,
          decoration: const InputDecoration(
            labelText: 'Family members',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          validator: (value) =>
              (int.tryParse(value ?? '') ?? 0) < 1 ? 'Enter at least 1' : null,
        ),
        SurveyFieldList(
          fields: surveyHeaderFields
              .where(
                (field) => !{
                  'informant',
                  'address',
                  'number_of_family',
                }.contains(field.key),
              )
              .toList(),
          data: surveyData,
          onChanged: onSurveyChanged,
          path: 'survey_header',
        ),
      ],
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _CheckboxGroup extends StatelessWidget {
  const _CheckboxGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final void Function(String option, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (checked) => onChanged(option, checked),
              ),
          ],
        ),
      ],
    );
  }
}

class _FamilySection extends StatelessWidget {
  const _FamilySection({
    required this.familyRows,
    required this.surveyData,
    required this.onMemberFieldChanged,
    required this.onFamilyProfileChanged,
  });

  final List<Map<String, dynamic>> familyRows;
  final Map<String, dynamic> surveyData;
  final void Function(int index, String key, Object? value)
  onMemberFieldChanged;
  final void Function(String key, Object? value) onFamilyProfileChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection(
      title: 'Family members',
      children: [
        for (var index = 0; index < familyRows.length; index++)
          _FamilyMemberEditor(
            index: index,
            row: familyRows[index],
            onChanged: (key, value) => onMemberFieldChanged(index, key, value),
          ),
        const Divider(height: 24),
        SurveyFieldList(
          fields: familyProfileFields,
          data: surveyData,
          onChanged: onFamilyProfileChanged,
          path: 'family_profile',
        ),
      ],
    );
  }
}

class _FamilyMemberEditor extends StatelessWidget {
  const _FamilyMemberEditor({
    required this.index,
    required this.row,
    required this.onChanged,
  });

  final int index;
  final Map<String, dynamic> row;
  final void Function(String key, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    final memberNumber = index + 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Member $memberNumber',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            _MemberNumberField(number: memberNumber),
            const SizedBox(height: 12),
            SurveyFieldList(
              fields: _familyMemberQuickFields,
              data: row,
              onChanged: onChanged,
              path: 'family_member_$index',
            ),
            const SizedBox(height: 12),
            _InlineSurveyExpansion(
              key: ValueKey('family_member_details_$index'),
              title: 'More member details',
              fields: _familyMemberDetailFields,
              data: row,
              onChanged: onChanged,
              path: 'family_member_details_$index',
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberNumberField extends StatelessWidget {
  const _MemberNumberField({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('member_no_$number'),
      initialValue: '$number',
      readOnly: true,
      enableInteractiveSelection: false,
      decoration: const InputDecoration(labelText: 'Member no.'),
    );
  }
}

final _familyMemberQuickFields = familyMemberFields
    .where(
      (field) => const {
        'name_of_family_member',
        'relationship_to_head',
        'gender',
        'age',
      }.contains(field.key),
    )
    .toList();

final _familyMemberDetailFields = familyMemberFields
    .where(
      (field) =>
          field.key != 'member_no' && !_familyMemberQuickFields.contains(field),
    )
    .toList();

class _InlineSurveyExpansion extends StatefulWidget {
  const _InlineSurveyExpansion({
    super.key,
    required this.title,
    required this.fields,
    required this.data,
    required this.onChanged,
    required this.path,
  });

  final String title;
  final List<SurveyField> fields;
  final Map<String, dynamic> data;
  final void Function(String key, Object? value) onChanged;
  final String path;

  @override
  State<_InlineSurveyExpansion> createState() => _InlineSurveyExpansionState();
}

class _InlineSurveyExpansionState extends State<_InlineSurveyExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: KasudloColors.border),
      ),
      child: ExpansionTile(
        title: Text(widget.title),
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: _expanded
            ? [
                SurveyFieldList(
                  fields: widget.fields,
                  data: widget.data,
                  onChanged: widget.onChanged,
                  path: widget.path,
                ),
              ]
            : const [],
      ),
    );
  }
}

Map<String, dynamic> _compactSurveyData(Map<String, dynamic> data) {
  final compacted = <String, dynamic>{};
  for (final entry in data.entries) {
    final value = _compactValue(entry.value);
    if (_valueHasContent(value)) {
      compacted[entry.key] = value;
    }
  }
  return compacted;
}

Object? _compactValue(Object? value) {
  if (value is String) {
    return value.trim();
  }
  if (value is List) {
    final compactedItems = <Object?>[];
    for (final item in value) {
      final compactedItem = _compactValue(item);
      if (_valueHasContent(compactedItem)) {
        compactedItems.add(compactedItem);
      }
    }
    return compactedItems;
  }
  if (value is Map) {
    return _compactSurveyData(Map<String, dynamic>.from(value));
  }
  return value;
}

bool _valueHasContent(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is List) {
    return value.isNotEmpty;
  }
  if (value is Map) {
    return value.isNotEmpty;
  }
  return true;
}
