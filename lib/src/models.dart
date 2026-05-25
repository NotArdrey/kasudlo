enum SyncStatus { draft, pending, syncing, synced, failed, conflict }

enum AccountRole { worker, patient, admin }

AccountRole accountRoleFromString(Object? value) {
  final normalized = '$value'.trim().toLowerCase();
  return switch (normalized) {
    'admin' => AccountRole.admin,
    'patient' => AccountRole.patient,
    _ => AccountRole.worker,
  };
}

extension AccountRoleLabel on AccountRole {
  String get label => switch (this) {
    AccountRole.admin => 'Admin',
    AccountRole.patient => 'Patient',
    AccountRole.worker => 'Worker',
  };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String email;
  final String fullName;
  final AccountRole role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: (json['id'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    fullName: (json['full_name'] as String?) ?? '',
    role: accountRoleFromString(json['role']),
  );
}

class AppPreferences {
  const AppPreferences({
    this.fieldRemindersEnabled = true,
    this.syncNotificationsEnabled = true,
    this.soundsEnabled = false,
    this.offlineModeEnabled = true,
    this.dataSaverEnabled = false,
    this.language = 'English',
  });

  final bool fieldRemindersEnabled;
  final bool syncNotificationsEnabled;
  final bool soundsEnabled;
  final bool offlineModeEnabled;
  final bool dataSaverEnabled;
  final String language;

  AppPreferences copyWith({
    bool? fieldRemindersEnabled,
    bool? syncNotificationsEnabled,
    bool? soundsEnabled,
    bool? offlineModeEnabled,
    bool? dataSaverEnabled,
    String? language,
  }) {
    return AppPreferences(
      fieldRemindersEnabled:
          fieldRemindersEnabled ?? this.fieldRemindersEnabled,
      syncNotificationsEnabled:
          syncNotificationsEnabled ?? this.syncNotificationsEnabled,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'field_reminders_enabled': fieldRemindersEnabled,
    'sync_notifications_enabled': syncNotificationsEnabled,
    'sounds_enabled': soundsEnabled,
    'offline_mode_enabled': offlineModeEnabled,
    'data_saver_enabled': dataSaverEnabled,
    'language': language,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final language = (json['language'] as String?)?.trim();

    return AppPreferences(
      fieldRemindersEnabled: (json['field_reminders_enabled'] as bool?) ?? true,
      syncNotificationsEnabled:
          (json['sync_notifications_enabled'] as bool?) ?? true,
      soundsEnabled: (json['sounds_enabled'] as bool?) ?? false,
      offlineModeEnabled: (json['offline_mode_enabled'] as bool?) ?? true,
      dataSaverEnabled: (json['data_saver_enabled'] as bool?) ?? false,
      language: language == null || language.isEmpty ? 'English' : language,
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final AccountRole role;
  final DateTime createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: (json['id'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    fullName: (json['full_name'] as String?) ?? '',
    role: accountRoleFromString(json['role']),
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String actorEmail;
  final String actorRole;
  final String action;
  final String entityType;
  final String? entityId;
  final String summary;
  final DateTime createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: (json['id'] as String?) ?? '',
    actorEmail: (json['actor_email'] as String?) ?? '',
    actorRole: (json['actor_role'] as String?) ?? '',
    action: (json['action'] as String?) ?? '',
    entityType: (json['entity_type'] as String?) ?? '',
    entityId: json['entity_id'] as String?,
    summary: (json['summary'] as String?) ?? '',
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class AiCareSuggestion {
  const AiCareSuggestion({
    required this.name,
    required this.type,
    required this.reason,
    required this.locationHint,
  });

  final String name;
  final String type;
  final String reason;
  final String locationHint;

  factory AiCareSuggestion.fromJson(Map<String, dynamic> json) =>
      AiCareSuggestion(
        name: (json['name'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        reason: (json['reason'] as String?) ?? '',
        locationHint: (json['location_hint'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'reason': reason,
    'location_hint': locationHint,
  };
}

class AiHealthGuidance {
  const AiHealthGuidance({
    required this.riskLevel,
    required this.summary,
    required this.concerningFindings,
    required this.recommendedActions,
    required this.followUpQuestions,
    required this.careSuggestions,
    required this.emergencyWarning,
    required this.disclaimer,
  });

  final String riskLevel;
  final String summary;
  final List<String> concerningFindings;
  final List<String> recommendedActions;
  final List<String> followUpQuestions;
  final List<AiCareSuggestion> careSuggestions;
  final String emergencyWarning;
  final String disclaimer;

  factory AiHealthGuidance.fromJson(
    Map<String, dynamic> json,
  ) => AiHealthGuidance(
    riskLevel: (json['risk_level'] as String?) ?? 'unknown',
    summary: (json['summary'] as String?) ?? '',
    concerningFindings: _stringList(json['concerning_findings']),
    recommendedActions: _stringList(json['recommended_actions']),
    followUpQuestions: _stringList(json['follow_up_questions']),
    careSuggestions: _mapList(
      json['care_suggestions'],
    ).map(AiCareSuggestion.fromJson).toList(),
    emergencyWarning: (json['emergency_warning'] as String?) ?? '',
    disclaimer:
        (json['disclaimer'] as String?) ??
        'AI guidance supports field triage and does not replace clinical judgment.',
  );

  Map<String, dynamic> toJson() => {
    'risk_level': riskLevel,
    'summary': summary,
    'concerning_findings': concerningFindings,
    'recommended_actions': recommendedActions,
    'follow_up_questions': followUpQuestions,
    'care_suggestions': careSuggestions
        .map((suggestion) => suggestion.toJson())
        .toList(),
    'emergency_warning': emergencyWarning,
    'disclaimer': disclaimer,
  };
}

class HealthTip {
  const HealthTip({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.attachmentBase64,
    required this.createdAt,
    required this.updatedAt,
    this.createdByEmail = '',
  });

  final String id;
  final String title;
  final String description;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String attachmentBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByEmail;

  bool get hasAttachment =>
      fileName.trim().isNotEmpty && attachmentBase64.trim().isNotEmpty;

  bool get isImage {
    final normalizedMime = mimeType.toLowerCase();
    final normalizedName = fileName.toLowerCase();
    return normalizedMime.startsWith('image/') ||
        normalizedName.endsWith('.png') ||
        normalizedName.endsWith('.jpg') ||
        normalizedName.endsWith('.jpeg') ||
        normalizedName.endsWith('.gif') ||
        normalizedName.endsWith('.webp');
  }

  HealthTip copyWith({
    String? title,
    String? description,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? attachmentBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByEmail,
  }) {
    return HealthTip(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      attachmentBase64: attachmentBase64 ?? this.attachmentBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByEmail: createdByEmail ?? this.createdByEmail,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'file_name': fileName,
    'mime_type': mimeType,
    'file_size': fileSize,
    'attachment_base64': attachmentBase64,
    'created_by_email': createdByEmail,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory HealthTip.fromJson(Map<String, dynamic> json) {
    final createdAt =
        _dateTimeValue(json['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return HealthTip(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      fileName: (json['file_name'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? '',
      fileSize: _intValue(json['file_size']) ?? 0,
      attachmentBase64: (json['attachment_base64'] as String?) ?? '',
      createdByEmail: (json['created_by_email'] as String?) ?? '',
      createdAt: createdAt,
      updatedAt: _dateTimeValue(json['updated_at']) ?? createdAt,
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.name,
    required this.age,
    required this.relationship,
    required this.healthProblems,
    required this.vaccinationStatus,
    required this.nutritionalStatus,
    this.details = const {},
  });

  final String name;
  final int? age;
  final String relationship;
  final List<String> healthProblems;
  final String vaccinationStatus;
  final String nutritionalStatus;
  final Map<String, dynamic> details;

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'relationship': relationship,
    'health_problems': healthProblems,
    'vaccination_status': vaccinationStatus,
    'nutritional_status': nutritionalStatus,
    'details': details,
  };

  Map<String, dynamic> toSurveyJson() {
    final surveyDetails = Map<String, dynamic>.from(details)
      ..remove('name')
      ..remove('relationship');

    surveyDetails['name_of_family_member'] =
        '${details['name_of_family_member'] ?? name}'.trim();
    if (age != null) {
      surveyDetails['age'] = age;
    }
    surveyDetails['relationship_to_head'] =
        '${details['relationship_to_head'] ?? relationship}'.trim();
    if (healthProblems.isNotEmpty) {
      surveyDetails['health_problems'] = healthProblems;
    }
    if (vaccinationStatus.trim().isNotEmpty) {
      surveyDetails['vaccination_status'] = vaccinationStatus;
    }
    if (nutritionalStatus.trim().isNotEmpty) {
      surveyDetails['nutritional_status'] = nutritionalStatus;
    }

    return surveyDetails;
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    name:
        (json['name'] as String?) ??
        (json['name_of_family_member'] as String?) ??
        '',
    age: _intValue(json['age']),
    relationship:
        (json['relationship'] as String?) ??
        (json['relationship_to_head'] as String?) ??
        '',
    healthProblems: _stringList(json['health_problems']),
    vaccinationStatus: (json['vaccination_status'] as String?) ?? '',
    nutritionalStatus: (json['nutritional_status'] as String?) ?? '',
    details: _detailsForFamilyMember(json),
  );

  factory FamilyMember.fromSurveyData(Map<String, dynamic> data) =>
      FamilyMember(
        name: '${data['name_of_family_member'] ?? data['name'] ?? ''}'.trim(),
        age: _intValue(data['age']),
        relationship:
            '${data['relationship_to_head'] ?? data['relationship'] ?? ''}'
                .trim(),
        healthProblems: _stringList(data['health_problems']),
        vaccinationStatus: (data['vaccination_status'] as String?) ?? '',
        nutritionalStatus: (data['nutritional_status'] as String?) ?? '',
        details: Map<String, dynamic>.from(data),
      );
}

class ReportEditHistoryEntry {
  const ReportEditHistoryEntry({
    required this.editedAt,
    required this.summary,
    required this.changes,
    this.editedBy,
  });

  final DateTime editedAt;
  final String summary;
  final List<String> changes;
  final String? editedBy;

  Map<String, dynamic> toJson() => {
    'edited_at': editedAt.toIso8601String(),
    'summary': summary,
    'changes': changes,
    'edited_by': editedBy,
  };

  factory ReportEditHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ReportEditHistoryEntry(
        editedAt:
            DateTime.tryParse('${json['edited_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        summary: (json['summary'] as String?) ?? '',
        changes: _stringList(json['changes']),
        editedBy: json['edited_by'] as String?,
      );
}

class HealthSubmission {
  const HealthSubmission({
    required this.clientSubmissionId,
    required this.respondentName,
    required this.respondentAge,
    required this.address,
    required this.familyMembersCount,
    required this.familyMembers,
    required this.healthProblems,
    required this.vaccinationStatus,
    required this.waterSanitation,
    required this.nutritionalStatus,
    required this.communityConcerns,
    this.surveyData = const {},
    required this.consentGiven,
    required this.notes,
    required this.createdAt,
    required this.syncStatus,
    this.updatedAt,
    this.remoteUpdatedAt,
    this.editHistory = const [],
    this.aiGuidance,
    this.lastError,
  });

  final String clientSubmissionId;
  final String respondentName;
  final int? respondentAge;
  final String address;
  final int familyMembersCount;
  final List<FamilyMember> familyMembers;
  final List<String> healthProblems;
  final String vaccinationStatus;
  final String waterSanitation;
  final String nutritionalStatus;
  final List<String> communityConcerns;
  final Map<String, dynamic> surveyData;
  final bool consentGiven;
  final String notes;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? updatedAt;
  final DateTime? remoteUpdatedAt;
  final List<ReportEditHistoryEntry> editHistory;
  final AiHealthGuidance? aiGuidance;
  final String? lastError;

  DateTime get effectiveUpdatedAt => updatedAt ?? createdAt;

  HealthSubmission copyWith({
    String? respondentName,
    Object? respondentAge = _unchanged,
    String? address,
    int? familyMembersCount,
    List<FamilyMember>? familyMembers,
    List<String>? healthProblems,
    String? vaccinationStatus,
    String? waterSanitation,
    String? nutritionalStatus,
    List<String>? communityConcerns,
    Map<String, dynamic>? surveyData,
    bool? consentGiven,
    String? notes,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    Object? updatedAt = _unchanged,
    Object? remoteUpdatedAt = _unchanged,
    List<ReportEditHistoryEntry>? editHistory,
    Object? aiGuidance = _unchanged,
    Object? lastError = _unchanged,
  }) => HealthSubmission(
    clientSubmissionId: clientSubmissionId,
    respondentName: respondentName ?? this.respondentName,
    respondentAge: identical(respondentAge, _unchanged)
        ? this.respondentAge
        : respondentAge as int?,
    address: address ?? this.address,
    familyMembersCount: familyMembersCount ?? this.familyMembersCount,
    familyMembers: familyMembers ?? this.familyMembers,
    healthProblems: healthProblems ?? this.healthProblems,
    vaccinationStatus: vaccinationStatus ?? this.vaccinationStatus,
    waterSanitation: waterSanitation ?? this.waterSanitation,
    nutritionalStatus: nutritionalStatus ?? this.nutritionalStatus,
    communityConcerns: communityConcerns ?? this.communityConcerns,
    surveyData: surveyData ?? this.surveyData,
    consentGiven: consentGiven ?? this.consentGiven,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: identical(updatedAt, _unchanged)
        ? this.updatedAt
        : updatedAt as DateTime?,
    remoteUpdatedAt: identical(remoteUpdatedAt, _unchanged)
        ? this.remoteUpdatedAt
        : remoteUpdatedAt as DateTime?,
    editHistory: editHistory ?? this.editHistory,
    aiGuidance: identical(aiGuidance, _unchanged)
        ? this.aiGuidance
        : aiGuidance as AiHealthGuidance?,
    lastError: identical(lastError, _unchanged)
        ? this.lastError
        : lastError as String?,
  );

  HealthSubmission withEditHistory({
    required HealthSubmission previous,
    required DateTime editedAt,
    String? editedBy,
  }) {
    final changes = reportEditChanges(previous: previous, next: this);
    final entry = ReportEditHistoryEntry(
      editedAt: editedAt,
      editedBy: editedBy,
      summary: changes.isEmpty
          ? 'Saved without field changes.'
          : '${changes.length} field${changes.length == 1 ? '' : 's'} updated.',
      changes: changes,
    );

    return copyWith(editHistory: [...editHistory, entry]);
  }

  Map<String, dynamic> toJson() => {
    'client_submission_id': clientSubmissionId,
    'respondent_name': respondentName,
    'respondent_age': respondentAge,
    'address': address,
    'family_members_count': familyMembersCount,
    'family_members': familyMembers.map((member) => member.toJson()).toList(),
    'health_problems': healthProblems,
    'vaccination_status': vaccinationStatus,
    'water_sanitation': waterSanitation,
    'nutritional_status': nutritionalStatus,
    'community_concerns': communityConcerns,
    'survey_data': surveyData,
    'consent_given': consentGiven,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'sync_status': syncStatus.name,
    'updated_at': effectiveUpdatedAt.toIso8601String(),
    'remote_updated_at': remoteUpdatedAt?.toIso8601String(),
    'edit_history': editHistory.map((entry) => entry.toJson()).toList(),
    'ai_health_guidance': aiGuidance?.toJson(),
    'last_error': lastError,
  };

  Map<String, dynamic> toRpcPayload() {
    final payload = <String, dynamic>{
      ...surveyData,
      'respondent_name': respondentName,
      'respondent_age': respondentAge,
      'address': address,
      'family_members_count': familyMembersCount,
      'family_members':
          surveyData['family_members'] ??
          familyMembers.map((member) => member.toSurveyJson()).toList(),
      'health_problems': healthProblems,
      'vaccination_status': vaccinationStatus,
      'water_sanitation': waterSanitation,
      'nutritional_status': nutritionalStatus,
      'community_concerns': communityConcerns,
      'consent_given': consentGiven,
      'notes': notes,
      'edit_history': editHistory.map((entry) => entry.toJson()).toList(),
      'ai_health_guidance': aiGuidance?.toJson(),
      'client_updated_at': effectiveUpdatedAt.toIso8601String(),
    };
    payload['survey_data'] = surveyData;
    return payload;
  }

  factory HealthSubmission.fromJson(Map<String, dynamic> json) {
    final payload = _dynamicMap(json['payload']);
    final surveyData = _surveyDataFromJson(json, payload);

    return HealthSubmission(
      clientSubmissionId: (json['client_submission_id'] as String?) ?? '',
      respondentName: (json['respondent_name'] as String?) ?? '',
      respondentAge: _intValue(json['respondent_age']),
      address: (json['address'] as String?) ?? '',
      familyMembersCount: _intValue(json['family_members_count']) ?? 0,
      familyMembers: _mapList(
        json['family_members'],
      ).map(FamilyMember.fromJson).toList(),
      healthProblems: _stringList(json['health_problems']),
      vaccinationStatus: (json['vaccination_status'] as String?) ?? '',
      waterSanitation: (json['water_sanitation'] as String?) ?? '',
      nutritionalStatus: (json['nutritional_status'] as String?) ?? '',
      communityConcerns: _stringList(json['community_concerns']),
      surveyData: surveyData,
      consentGiven: (json['consent_given'] as bool?) ?? false,
      notes: (json['notes'] as String?) ?? '',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      syncStatus: SyncStatus.values.firstWhere(
        (status) => status.name == json['sync_status'],
        orElse: () => SyncStatus.draft,
      ),
      updatedAt: _dateTimeValue(
        json['updated_at'] ?? json['client_updated_at'],
      ),
      remoteUpdatedAt: _dateTimeValue(json['remote_updated_at']),
      editHistory: _editHistoryList(json['edit_history']),
      aiGuidance: _aiGuidanceFromJson(json, payload, surveyData),
      lastError: json['last_error'] as String?,
    );
  }

  factory HealthSubmission.fromRemoteJson(Map<String, dynamic> json) =>
      HealthSubmission.fromJson({
        ...json,
        'created_at': json['created_at'] ?? json['submitted_at'],
        'sync_status': SyncStatus.synced.name,
        'updated_at': _clientUpdatedAtFromPayload(json) ?? json['updated_at'],
        'remote_updated_at': json['updated_at'] ?? json['submitted_at'],
        'last_error': null,
      });

  bool hasSameAssessmentContent(HealthSubmission other) {
    return respondentName == other.respondentName &&
        respondentAge == other.respondentAge &&
        address == other.address &&
        familyMembersCount == other.familyMembersCount &&
        _dynamicValuesEqual(
          familyMembers.map((member) => member.toJson()).toList(),
          other.familyMembers.map((member) => member.toJson()).toList(),
        ) &&
        _stringListsEqual(healthProblems, other.healthProblems) &&
        vaccinationStatus == other.vaccinationStatus &&
        waterSanitation == other.waterSanitation &&
        nutritionalStatus == other.nutritionalStatus &&
        _stringListsEqual(communityConcerns, other.communityConcerns) &&
        _dynamicValuesEqual(surveyData, other.surveyData) &&
        consentGiven == other.consentGiven &&
        notes == other.notes &&
        _dynamicValuesEqual(
          editHistory.map((entry) => entry.toJson()).toList(),
          other.editHistory.map((entry) => entry.toJson()).toList(),
        ) &&
        _dynamicValuesEqual(aiGuidance?.toJson(), other.aiGuidance?.toJson());
  }
}

const _unchanged = Object();

List<String> reportEditChanges({
  required HealthSubmission previous,
  required HealthSubmission next,
}) {
  final changes = <String>[];

  void addValueChange(String label, Object? oldValue, Object? newValue) {
    if (_historyValuesEqual(oldValue, newValue)) {
      return;
    }

    changes.add(
      '$label changed from ${_historyValueLabel(oldValue)} to ${_historyValueLabel(newValue)}.',
    );
  }

  addValueChange('Informant', previous.respondentName, next.respondentName);
  addValueChange('Age', previous.respondentAge, next.respondentAge);
  addValueChange('Address', previous.address, next.address);
  addValueChange(
    'Family members',
    previous.familyMembersCount,
    next.familyMembersCount,
  );
  addValueChange(
    'Health problems',
    previous.healthProblems,
    next.healthProblems,
  );
  addValueChange(
    'Vaccination status',
    previous.vaccinationStatus,
    next.vaccinationStatus,
  );
  addValueChange(
    'Water and sanitation',
    previous.waterSanitation,
    next.waterSanitation,
  );
  addValueChange(
    'Nutritional status',
    previous.nutritionalStatus,
    next.nutritionalStatus,
  );
  addValueChange(
    'Community concerns',
    previous.communityConcerns,
    next.communityConcerns,
  );
  addValueChange(
    'Survey responses',
    _historySurveyData(previous),
    _historySurveyData(next),
  );
  addValueChange('Notes', previous.notes, next.notes);

  return changes;
}

bool reportEditHistoryEquals(
  List<ReportEditHistoryEntry> first,
  List<ReportEditHistoryEntry> second,
) {
  return _dynamicValuesEqual(
    first.map((entry) => entry.toJson()).toList(),
    second.map((entry) => entry.toJson()).toList(),
  );
}

Map<String, dynamic> _historySurveyData(HealthSubmission submission) {
  final surveyData = Map<String, dynamic>.from(submission.surveyData);

  void removeMirroredValue(String key, Object? value) {
    if (_dynamicValuesEqual(surveyData[key], value)) {
      surveyData.remove(key);
    }
  }

  removeMirroredValue('informant', submission.respondentName);
  removeMirroredValue('address', submission.address);
  removeMirroredValue('number_of_family', submission.familyMembersCount);
  removeMirroredValue('health_problems', submission.healthProblems);
  removeMirroredValue('vaccination_status', submission.vaccinationStatus);
  removeMirroredValue('water_sanitation', submission.waterSanitation);
  removeMirroredValue('nutritional_status', submission.nutritionalStatus);
  removeMirroredValue('community_concerns', submission.communityConcerns);
  removeMirroredValue('notes', submission.notes);
  if (surveyData['account_create_requested'] == false) {
    surveyData.remove('account_create_requested');
  }
  if ('${surveyData['account_email'] ?? ''}'.trim().isEmpty) {
    surveyData.remove('account_email');
  }

  return surveyData;
}

class ReportSummary {
  const ReportSummary({
    required this.totalHouseholds,
    required this.totalFamilyMembers,
    required this.pendingDrafts,
    required this.syncedRecords,
    required this.healthProblems,
    required this.communityConcerns,
    required this.vaccinationStatuses,
    required this.nutritionalStatuses,
    required this.waterSanitationStatuses,
  });

  final int totalHouseholds;
  final int totalFamilyMembers;
  final int pendingDrafts;
  final int syncedRecords;
  final Map<String, int> healthProblems;
  final Map<String, int> communityConcerns;
  final Map<String, int> vaccinationStatuses;
  final Map<String, int> nutritionalStatuses;
  final Map<String, int> waterSanitationStatuses;

  bool get hasData => totalHouseholds > 0;

  static ReportSummary fromSubmissions(List<HealthSubmission> submissions) {
    final healthProblems = <String, int>{};
    final concerns = <String, int>{};
    final vaccines = <String, int>{};
    final nutrition = <String, int>{};
    final water = <String, int>{};

    for (final submission in submissions) {
      for (final item in submission.healthProblems) {
        _increment(healthProblems, item);
      }
      for (final item in submission.communityConcerns) {
        _increment(concerns, item);
      }
      _increment(vaccines, submission.vaccinationStatus);
      _increment(nutrition, submission.nutritionalStatus);
      _increment(water, submission.waterSanitation);
    }

    return ReportSummary(
      totalHouseholds: submissions.length,
      totalFamilyMembers: submissions.fold<int>(
        0,
        (sum, submission) => sum + submission.familyMembersCount,
      ),
      pendingDrafts: submissions
          .where(
            (submission) =>
                submission.syncStatus == SyncStatus.pending ||
                submission.syncStatus == SyncStatus.failed ||
                submission.syncStatus == SyncStatus.conflict ||
                submission.syncStatus == SyncStatus.draft,
          )
          .length,
      syncedRecords: submissions
          .where((submission) => submission.syncStatus == SyncStatus.synced)
          .length,
      healthProblems: healthProblems,
      communityConcerns: concerns,
      vaccinationStatuses: vaccines,
      nutritionalStatuses: nutrition,
      waterSanitationStatuses: water,
    );
  }
}

void _increment(Map<String, int> values, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    return;
  }
  values[value] = (values[value] ?? 0) + 1;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _dynamicMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

Map<String, dynamic> _detailsForFamilyMember(Map<String, dynamic> json) {
  final details = _dynamicMap(json['details']);
  if (details.isNotEmpty) {
    return details;
  }

  final copied = Map<String, dynamic>.from(json);
  copied.remove('details');
  return copied;
}

Map<String, dynamic> _surveyDataFromJson(
  Map<String, dynamic> json,
  Map<String, dynamic> payload,
) {
  final directSurveyData = _dynamicMap(json['survey_data']);
  if (directSurveyData.isNotEmpty) {
    return directSurveyData;
  }

  final nestedSurveyData = _dynamicMap(payload['survey_data']);
  if (nestedSurveyData.isNotEmpty) {
    return nestedSurveyData;
  }

  return payload;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
}

DateTime? _dateTimeValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String? _clientUpdatedAtFromPayload(Map<String, dynamic> json) {
  final payload = _dynamicMap(json['payload']);
  final value = payload['client_updated_at'];
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

List<ReportEditHistoryEntry> _editHistoryList(Object? value) {
  return _mapList(value).map(ReportEditHistoryEntry.fromJson).toList();
}

AiHealthGuidance? _aiGuidanceFromJson(
  Map<String, dynamic> json,
  Map<String, dynamic> payload,
  Map<String, dynamic> surveyData,
) {
  final guidance = _dynamicMap(
    json['ai_health_guidance'] ??
        payload['ai_health_guidance'] ??
        surveyData['ai_health_guidance'],
  );
  if (guidance.isEmpty) {
    return null;
  }
  return AiHealthGuidance.fromJson(guidance);
}

bool _historyValuesEqual(Object? first, Object? second) {
  if (first is List<String> && second is List<String>) {
    return _stringListsEqual(first, second);
  }
  if (first is Map && second is Map) {
    return _mapsEqual(
      Map<String, dynamic>.from(first),
      Map<String, dynamic>.from(second),
    );
  }
  return first == second;
}

bool _stringListsEqual(List<String> first, List<String> second) {
  final sortedFirst = first.toList()..sort();
  final sortedSecond = second.toList()..sort();

  if (sortedFirst.length != sortedSecond.length) {
    return false;
  }

  for (var index = 0; index < sortedFirst.length; index++) {
    if (sortedFirst[index] != sortedSecond[index]) {
      return false;
    }
  }

  return true;
}

bool _mapsEqual(Map<String, dynamic> first, Map<String, dynamic> second) {
  if (first.length != second.length) {
    return false;
  }

  for (final key in first.keys) {
    if (!second.containsKey(key)) {
      return false;
    }
    final firstValue = first[key];
    final secondValue = second[key];
    if (!_dynamicValuesEqual(firstValue, secondValue)) {
      return false;
    }
  }

  return true;
}

bool _dynamicValuesEqual(Object? first, Object? second) {
  if (first is Map && second is Map) {
    return _mapsEqual(
      Map<String, dynamic>.from(first),
      Map<String, dynamic>.from(second),
    );
  }
  if (first is List && second is List) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (!_dynamicValuesEqual(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }
  return '$first' == '$second';
}

String _historyValueLabel(Object? value) {
  if (value == null) {
    return 'blank';
  }
  if (value is List<String>) {
    return _shortHistoryText(value.isEmpty ? 'none' : value.join(', '));
  }
  if (value is Map<String, dynamic>) {
    if (value.isEmpty) {
      return 'none';
    }
    return '${value.length} saved survey field${value.length == 1 ? '' : 's'}';
  }

  final text = '$value'.trim();
  return _shortHistoryText(text.isEmpty ? 'blank' : text);
}

String _shortHistoryText(String text) {
  if (text.length <= 90) {
    return text;
  }
  return '${text.substring(0, 87)}...';
}
