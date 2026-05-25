import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';

class GroqGateway {
  static const _chatCompletionsUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static bool get isConfigured => AppConfig.hasGroq;

  static Future<AiHealthGuidance> analyzeAssessment(
    HealthSubmission submission,
  ) async {
    if (!isConfigured) {
      throw StateError('Groq AI key is not configured.');
    }

    final response = await http.post(
      Uri.parse(_chatCompletionsUrl),
      headers: {
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openai/gpt-oss-20b',
        'temperature': 0.2,
        'max_completion_tokens': 1400,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a public health triage assistant for KASUDLO household surveys. Analyze the survey data, do not diagnose, and give practical next steps for a field worker. If findings may be urgent, clearly advise immediate referral or emergency care. Suggest nearby care using the respondent address; when an exact hospital cannot be verified, recommend the nearest barangay health station, RHU, municipal/city hospital, or emergency department and say the worker must verify current availability locally. Keep text concise and suitable for community health work.',
          },
          {
            'role': 'user',
            'content': jsonEncode({
              'task':
                  'Assess this household health record and return the required JSON.',
              'submission': _compactSubmission(submission),
            }),
          },
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'kasudlo_health_guidance',
            'strict': true,
            'schema': _guidanceSchema,
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_groqErrorMessage(response));
    }

    final content = _completionContent(jsonDecode(response.body));
    if (content is! String || content.trim().isEmpty) {
      throw StateError('Groq AI returned an empty response.');
    }

    final guidance = jsonDecode(content);
    if (guidance is! Map) {
      throw StateError('Groq AI returned an invalid guidance format.');
    }

    return AiHealthGuidance.fromJson(Map<String, dynamic>.from(guidance));
  }

  static Map<String, dynamic> _compactSubmission(HealthSubmission submission) {
    return {
      'respondent_name': submission.respondentName,
      'respondent_age': submission.respondentAge,
      'address': submission.address,
      'family_members_count': submission.familyMembersCount,
      'family_members': submission.familyMembers
          .map((member) => member.toJson())
          .toList(),
      'health_problems': submission.healthProblems,
      'vaccination_status': submission.vaccinationStatus,
      'water_sanitation': submission.waterSanitation,
      'nutritional_status': submission.nutritionalStatus,
      'community_concerns': submission.communityConcerns,
      'notes': submission.notes,
      'survey_data': submission.surveyData,
    };
  }

  static String _groqErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = decoded['error']['message'];
        if (message != null) {
          return '$message';
        }
      }
    } catch (_) {
      return 'Groq AI request failed (${response.statusCode}).';
    }
    return 'Groq AI request failed (${response.statusCode}).';
  }

  static String? _completionContent(Object? decoded) {
    if (decoded is! Map) {
      return null;
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      return null;
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      return null;
    }
    final content = message['content'];
    return content is String ? content : null;
  }
}

const Map<String, dynamic> _guidanceSchema = {
  'type': 'object',
  'properties': {
    'risk_level': {
      'type': 'string',
      'enum': ['low', 'moderate', 'high', 'urgent'],
    },
    'summary': {'type': 'string'},
    'concerning_findings': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'recommended_actions': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'follow_up_questions': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'care_suggestions': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'type': {'type': 'string'},
          'reason': {'type': 'string'},
          'location_hint': {'type': 'string'},
        },
        'required': ['name', 'type', 'reason', 'location_hint'],
        'additionalProperties': false,
      },
    },
    'emergency_warning': {'type': 'string'},
    'disclaimer': {'type': 'string'},
  },
  'required': [
    'risk_level',
    'summary',
    'concerning_findings',
    'recommended_actions',
    'follow_up_questions',
    'care_suggestions',
    'emergency_warning',
    'disclaimer',
  ],
  'additionalProperties': false,
};
