import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

interface BanUserInput {
  reported_profile_id: string;
  report_id?: string | null;
  note?: string | null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { Allow: "POST, OPTIONS" } });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabase = createClient(url, serviceRoleKey);

  let body: BanUserInput;
  try {
    body = (await req.json()) as BanUserInput;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { reported_profile_id, report_id, note } = body;
  if (!reported_profile_id) {
    return jsonResponse({ error: "invalid_params" }, 400);
  }

  // Verify caller profile has backoffice access
  const { data: moderator, error: moderatorError } = await supabase
    .from("profiles")
    .select("id, can_access_backoffice, school_id, role")
    .eq("user_id", userData.user.id)
    .maybeSingle();

  if (moderatorError || !moderator || !moderator.can_access_backoffice) {
    console.warn("Moderator not allowed to ban user", {
      user_id: userData.user.id,
      error: moderatorError?.message,
    });
    return jsonResponse({ error: "forbidden" }, 403);
  }
  const moderator_profile_id = moderator.id as string;
  const actorSchoolId = typeof moderator.school_id === "string" && moderator.school_id !== ""
    ? moderator.school_id
    : null;
  const actorIsSuperAdmin = moderator.role === "super_admin";

  // Multi-school guard: a moderator may not ban a user of a different school.
  // Applied only when BOTH school_ids are known (non-null), so legacy profiles
  // without school_id keep the legacy behavior. super_admin actors are exempt.
  // Target lookup is best-effort: on failure the guard is skipped (legacy path).
  if (!actorIsSuperAdmin && actorSchoolId) {
    try {
      const { data: targetProfile, error: targetError } = await supabase
        .from("profiles")
        .select("school_id")
        .eq("id", reported_profile_id)
        .maybeSingle();
      const targetSchoolId = !targetError
          && targetProfile
          && typeof targetProfile.school_id === "string"
          && targetProfile.school_id !== ""
        ? targetProfile.school_id
        : null;
      if (targetSchoolId && targetSchoolId !== actorSchoolId) {
        console.warn("Cross-school moderation blocked (ban_user)", {
          moderator_profile_id,
          actor_school_id: actorSchoolId,
          target_school_id: targetSchoolId,
          reported_profile_id,
        });
        return jsonResponse({ error: "forbidden", message: "cross_school_forbidden" }, 403);
      }
    } catch (e) {
      console.warn("Cross-school guard lookup failed (ban_user); continuing", {
        reported_profile_id,
        error: (e as Error).message,
      });
    }
  }

  // Insert or update banned_users record
  const { error: banError } = await supabase.from("banned_users").upsert(
    {
      profile_id: reported_profile_id,
      banned_by_profile_id: moderator_profile_id,
      reason: note ?? null,
      note: note ?? null,
      report_id: report_id ?? null,
      created_at: new Date().toISOString(),
    },
    { onConflict: "profile_id" },
  );

  if (banError) {
    console.error("Failed to insert into banned_users:", banError);
    return jsonResponse({ error: "ban_failed" }, 500);
  }

  // Update content_reports if provided
  if (report_id) {
    const { error: reportUpdateError } = await supabase
      .from("content_reports")
      .update({
        status: "resolved",
        action_taken: "banned",
        moderator_profile_id,
        resolved_at: new Date().toISOString(),
        moderator_note: note ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", report_id);

    if (reportUpdateError) {
      console.error("Failed to update content_reports after ban:", reportUpdateError);
    }
  }

  // Insert audit log
  const { error: auditError } = await supabase.from("moderation_actions").insert({
    moderator_profile_id,
    action: "ban_user",
    target_type: "profile",
    target_id: reported_profile_id,
    report_id: report_id ?? null,
    metadata: {
      note: note ?? null,
    },
  });

  if (auditError) {
    console.error("Failed to insert moderation_actions (ban_user):", auditError);
  }

  return jsonResponse({ ok: true });
});

