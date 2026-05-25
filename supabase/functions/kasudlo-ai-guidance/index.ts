// @ts-ignore
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
// @ts-ignore
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

declare const Deno: {
  env: {
    get: (key: string) => string | undefined;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const groqChatCompletionsUrl =
  "https://api.groq.com/openai/v1/chat/completions";

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, status = 400) {
  return jsonResponse({ error: message }, status);
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

function textValue(value: unknown) {
  return String(value ?? "").trim();
}

function compactSubmission(rawSubmission: any) {
  const surveyData = rawSubmission?.survey_data ?? {};
  return {
    respondent_name: textValue(rawSubmission?.respondent_name),
    respondent_age: rawSubmission?.respondent_age ?? null,
    address: textValue(rawSubmission?.address),
    family_members_count: rawSubmission?.family_members_count ?? 0,
    family_members:
      rawSubmission?.family_members ?? surveyData.family_members ?? [],
    health_problems: rawSubmission?.health_problems ?? [],
    vaccination_status: textValue(rawSubmission?.vaccination_status),
    water_sanitation: textValue(rawSubmission?.water_sanitation),
    nutritional_status: textValue(rawSubmission?.nutritional_status),
    community_concerns: rawSubmission?.community_concerns ?? [],
    notes: textValue(rawSubmission?.notes),
    survey_data: surveyData,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  try {
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const publishableKey =
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";
    const groqApiKey = requiredEnv("GROQ_API_KEY");
    const authorization = req.headers.get("Authorization") ?? "";
    const jwt = authorization.replace(/^Bearer\s+/i, "").trim();

    if (!jwt) {
      return errorResponse("Sign in before using AI guidance.", 401);
    }

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(jwt);

    if (userError || !user?.id) {
      return errorResponse("Your session could not be verified.", 401);
    }

    const body = await req.json().catch(() => ({}));
    const submission = compactSubmission(body.submission);
    if (!submission.respondent_name || !submission.address) {
      return errorResponse("Respondent name and address are required.");
    }

    const groqResponse = await fetch(groqChatCompletionsUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${groqApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-20b",
        temperature: 0.2,
        max_completion_tokens: 1400,
        messages: [
          {
            role: "system",
            content:
              "You are a public health triage assistant for KASUDLO household surveys. Analyze the survey data, do not diagnose, and give practical next steps for a field worker. If findings may be urgent, clearly advise immediate referral or emergency care. Suggest nearby care using the respondent address; when an exact hospital cannot be verified, recommend the nearest barangay health station, RHU, municipal/city hospital, or emergency department and say the worker must verify current availability locally. Keep text concise and suitable for community health work.",
          },
          {
            role: "user",
            content: JSON.stringify({
              task:
                "Assess this household health record and return the required JSON.",
              submission,
            }),
          },
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "kasudlo_health_guidance",
            strict: true,
            schema: {
              type: "object",
              properties: {
                risk_level: {
                  type: "string",
                  enum: ["low", "moderate", "high", "urgent"],
                },
                summary: { type: "string" },
                concerning_findings: {
                  type: "array",
                  items: { type: "string" },
                },
                recommended_actions: {
                  type: "array",
                  items: { type: "string" },
                },
                follow_up_questions: {
                  type: "array",
                  items: { type: "string" },
                },
                care_suggestions: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      name: { type: "string" },
                      type: { type: "string" },
                      reason: { type: "string" },
                      location_hint: { type: "string" },
                    },
                    required: ["name", "type", "reason", "location_hint"],
                    additionalProperties: false,
                  },
                },
                emergency_warning: { type: "string" },
                disclaimer: { type: "string" },
              },
              required: [
                "risk_level",
                "summary",
                "concerning_findings",
                "recommended_actions",
                "follow_up_questions",
                "care_suggestions",
                "emergency_warning",
                "disclaimer",
              ],
              additionalProperties: false,
            },
          },
        },
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      return errorResponse(
        `Groq AI request failed: ${errorText || groqResponse.statusText}`,
        502,
      );
    }

    const completion = await groqResponse.json();
    const content = completion?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      return errorResponse("Groq AI returned an empty response.", 502);
    }

    return jsonResponse({ guidance: JSON.parse(content) });
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Unable to generate AI guidance.",
      500,
    );
  }
});
