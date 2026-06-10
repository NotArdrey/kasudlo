// @ts-ignore
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
// @ts-ignore
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
// @ts-ignore
import nodemailer from "npm:nodemailer@6.9.16";

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

function normalizeText(value: unknown) {
  return String(value ?? "").trim();
}

function normalizeIds(value: unknown) {
  if (!Array.isArray(value)) {
    return [];
  }

  const seen = new Set<string>();
  const ids: string[] = [];
  for (const rawId of value) {
    const id = normalizeText(rawId);
    if (!id || seen.has(id)) {
      continue;
    }
    seen.add(id);
    ids.push(id);
  }
  return ids;
}

function canManageHealthTips(role: unknown) {
  const normalized = normalizeText(role).toLowerCase();
  return normalized === "admin" ||
    normalized === "nurse" ||
    normalized === "worker";
}

function isValidEmail(value: unknown) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeText(value));
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function excerpt(value: string) {
  const trimmed = value.replace(/\s+/g, " ").trim();
  if (trimmed.length <= 360) {
    return trimmed;
  }
  return `${trimmed.slice(0, 357)}...`;
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
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const publishableKey =
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";

    const authorization = req.headers.get("Authorization") ?? "";
    const jwt = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) {
      return errorResponse("Sign in to continue.", 401);
    }

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(jwt);

    if (userError || !user?.id) {
      return errorResponse("Your session could not be verified.", 401);
    }

    const { data: actorProfile, error: actorError } = await adminClient
      .from("profiles")
      .select("id, role")
      .eq("id", user.id)
      .maybeSingle();

    if (actorError) {
      throw actorError;
    }
    if (!canManageHealthTips(actorProfile?.role)) {
      return errorResponse("Only admins and nurses can email teaching.", 403);
    }

    const body = await req.json().catch(() => ({}));
    const healthTipId = normalizeText(body.health_tip_id);
    if (!healthTipId) {
      return errorResponse("Health teaching id is required.");
    }

    const { data: healthTip, error: tipError } = await adminClient
      .from("health_tips")
      .select("id, title, description, target_patient_id, target_patient_ids")
      .eq("id", healthTipId)
      .single();

    if (tipError || !healthTip) {
      return errorResponse("Health teaching was not found.", 404);
    }

    let targetIds = normalizeIds(healthTip.target_patient_ids);
    const legacyTargetId = normalizeText(healthTip.target_patient_id);
    if (targetIds.length === 0 && legacyTargetId) {
      targetIds = [legacyTargetId];
    }

    let profileQuery = adminClient
      .from("profiles")
      .select("id, email, full_name")
      .eq("role", "patient");
    if (targetIds.length > 0) {
      profileQuery = profileQuery.in("id", targetIds);
    }

    const { data: recipients, error: recipientsError } = await profileQuery;
    if (recipientsError) {
      throw recipientsError;
    }

    const emails = [...new Set(
      (recipients ?? [])
        .map((recipient: any) => normalizeText(recipient.email).toLowerCase())
        .filter(isValidEmail),
    )];

    if (emails.length === 0) {
      return jsonResponse({ sent: 0 });
    }

    const fromEmail = requiredEnv("KASUDLO_SMTP_FROM");
    const transporter = nodemailer.createTransport({
      host: Deno.env.get("KASUDLO_SMTP_HOST") ?? "smtp.gmail.com",
      port: Number(Deno.env.get("KASUDLO_SMTP_PORT") ?? "465"),
      secure: (Deno.env.get("KASUDLO_SMTP_SECURE") ?? "true") !== "false",
      auth: {
        user: requiredEnv("KASUDLO_SMTP_USER"),
        pass: requiredEnv("KASUDLO_SMTP_PASS"),
      },
    });

    const title = normalizeText(healthTip.title) || "New health teaching";
    const description = excerpt(normalizeText(healthTip.description));
    const text = [
      `New health teaching: ${title}`,
      "",
      description,
      "",
      "Open KASUDLO to view the full teaching and attachments.",
    ].join("\n");
    const html = [
      `<p>New health teaching is available in KASUDLO.</p>`,
      `<h2>${escapeHtml(title)}</h2>`,
      description ? `<p>${escapeHtml(description)}</p>` : "",
      `<p>Open KASUDLO to view the full teaching and attachments.</p>`,
    ].join("");

    await transporter.sendMail({
      from: `"KASUDLO" <${fromEmail}>`,
      bcc: emails,
      subject: `New health teaching: ${title}`,
      text,
      html,
    });

    await adminClient.from("audit_logs").insert({
      actor_user_id: user.id,
      actor_email: user.email ?? "",
      actor_role: normalizeText(actorProfile?.role) || "nurse",
      action: "health_tip.email",
      entity_type: "health_tip",
      entity_id: healthTipId,
      summary: `Emailed health teaching "${title}".`,
      metadata: { recipient_count: emails.length },
    });

    return jsonResponse({ sent: emails.length });
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Unable to email teaching.",
      500,
    );
  }
});
