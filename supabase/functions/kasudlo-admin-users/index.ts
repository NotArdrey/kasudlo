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

type AccountRole = "worker" | "patient" | "admin";

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

function normalizeEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

function normalizeText(value: unknown) {
  return String(value ?? "").trim();
}

function parseRole(value: unknown): AccountRole | null {
  const role = normalizeText(value).toLowerCase();
  return role === "worker" || role === "patient" || role === "admin"
    ? role
    : null;
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function friendlyAuthError(error: any) {
  const message = String(error?.message || "Unable to create account.");
  if (/already|registered|exists/i.test(message)) {
    return { message: "An account with this email already exists.", status: 409 };
  }
  return { message, status: 400 };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  let adminClient;
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
      return errorResponse("Sign in as an admin to continue.", 401);
    }

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    adminClient = createClient(supabaseUrl, serviceRoleKey, {
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

    if (actorProfile?.role !== "admin") {
      return errorResponse("Only admins can manage accounts.", 403);
    }

    const body = await req.json().catch(() => ({}));
    const action = normalizeText(body.action);

    if (action === "list") {
      const search = normalizeText(body.search).toLowerCase();
      const { data, error } = await adminClient
        .from("profiles")
        .select("id, email, full_name, role, created_at")
        .order("created_at", { ascending: false });

      if (error) {
        throw error;
      }

      const users = (data ?? []).filter((profile: any) => {
        if (!search) return true;
        return [
          profile.email,
          profile.full_name,
          profile.role,
        ].some((value) => normalizeText(value).toLowerCase().includes(search));
      });

      return jsonResponse({ users });
    }

    if (action !== "create") {
      return errorResponse("Unknown admin user action.", 400);
    }

    const fullName = normalizeText(body.full_name);
    const email = normalizeEmail(body.email);
    const password = String(body.password ?? "");
    const role = parseRole(body.role);

    if (!fullName) {
      return errorResponse("Full name is required.");
    }
    if (!isValidEmail(email)) {
      return errorResponse("Enter a valid email address.");
    }
    if (password.length < 6) {
      return errorResponse("Use at least 6 password characters.");
    }
    if (!role) {
      return errorResponse("Choose a valid account role.");
    }

    const { data: created, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
        app_metadata: { kasudlo_role: role },
      });

    if (createError || !created?.user?.id) {
      const friendly = friendlyAuthError(createError);
      return errorResponse(friendly.message, friendly.status);
    }

    const targetUserId = created.user.id;
    const { error: profileError } = await adminClient
      .from("profiles")
      .upsert({
        id: targetUserId,
        email,
        full_name: fullName,
        role,
        created_by: user.id,
        updated_at: new Date().toISOString(),
      }, { onConflict: "id" });

    if (profileError) {
      await adminClient.auth.admin.deleteUser(targetUserId);
      throw profileError;
    }

    const { error: eventError } = await adminClient
      .from("admin_account_events")
      .insert({
        actor_user_id: user.id,
        target_user_id: targetUserId,
        target_email: email,
        target_role: role,
        action: "create_user",
        metadata: { full_name: fullName },
      });

    if (eventError) {
      throw eventError;
    }

    await adminClient
      .from("audit_logs")
      .insert({
        actor_user_id: user.id,
        actor_email: user.email ?? "",
        actor_role: "admin",
        action: "admin.account.create",
        entity_type: "account",
        entity_id: targetUserId,
        summary: `Created ${role} account for ${email}.`,
        metadata: { email, role, full_name: fullName },
      });

    return jsonResponse({
      user: {
        id: targetUserId,
        email,
        full_name: fullName,
        role,
        created_at: created.user.created_at,
      },
    }, 201);
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Unable to complete admin action.",
      500,
    );
  }
});
