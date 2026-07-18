import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type TargetType =
  | "suggestion"
  | "suggestion_comment"
  | "announcement"
  | "poll_comment"
  | "chat_message"
  | "profile";

interface DeleteContentInput {
  target_type: TargetType;
  target_id: string;
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

  let body: DeleteContentInput;
  try {
    body = (await req.json()) as DeleteContentInput;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { target_type, target_id, report_id, note } = body;
  if (!target_type || !target_id) {
    return jsonResponse({ error: "invalid_params" }, 400);
  }

  // Verify caller profile has backoffice access
  const { data: moderator, error: moderatorError } = await supabase
    .from("profiles")
    .select("id, can_access_backoffice, school_id, role")
    .eq("user_id", userData.user.id)
    .maybeSingle();

  if (moderatorError || !moderator || !moderator.can_access_backoffice) {
    console.warn("Moderator not allowed to delete content", {
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

  // Helper to load original content best-effort
  async function fetchOriginal(): Promise<Record<string, unknown> | null> {
    try {
      switch (target_type) {
        case "suggestion": {
          const { data } = await supabase
            .from("suggestions")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        case "suggestion_comment": {
          const { data } = await supabase
            .from("suggestion_comments")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        case "announcement": {
          const { data } = await supabase
            .from("announcements")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        case "poll_comment": {
          const { data } = await supabase
            .from("poll_comments")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        case "chat_message": {
          const { data } = await supabase
            .from("chat_messages")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        case "profile": {
          const { data } = await supabase
            .from("profiles")
            .select("*")
            .eq("id", target_id)
            .maybeSingle();
          return (data as Record<string, unknown>) ?? null;
        }
        default:
          return null;
      }
    } catch (e) {
      console.warn("Failed to fetch original content", { target_type, target_id, error: (e as Error).message });
      return null;
    }
  }

  const original = await fetchOriginal();

  // Multi-school guard: a moderator may not act on content that belongs to a
  // different school. Applied only when BOTH school_ids are known (non-null),
  // so legacy rows/profiles without school_id keep the legacy behavior.
  // super_admin actors are exempt.
  if (!actorIsSuperAdmin && actorSchoolId) {
    const rawTargetSchoolId = original ? original["school_id"] : null;
    const targetSchoolId = typeof rawTargetSchoolId === "string" && rawTargetSchoolId !== ""
      ? rawTargetSchoolId
      : null;
    if (targetSchoolId && targetSchoolId !== actorSchoolId) {
      console.warn("Cross-school moderation blocked (delete_content)", {
        moderator_profile_id,
        actor_school_id: actorSchoolId,
        target_school_id: targetSchoolId,
        target_type,
        target_id,
      });
      return jsonResponse({ error: "forbidden", message: "cross_school_forbidden" }, 403);
    }
  }

  // Insert tombstone
  const { error: tombstoneError } = await supabase.from("content_tombstones").insert({
    target_type,
    target_id,
    deleted_by_profile_id: moderator_profile_id,
    report_id: report_id ?? null,
    reason: note ?? null,
    original_content: original,
  });

  if (tombstoneError) {
    console.error("Failed to insert content_tombstone:", tombstoneError);
    return jsonResponse({ error: "tombstone_failed" }, 500);
  }

  // Delete or anonymize original content
  try {
    switch (target_type) {
      case "suggestion":
        await supabase.from("suggestions").delete().eq("id", target_id);
        break;
      case "suggestion_comment":
        await supabase.from("suggestion_comments").delete().eq("id", target_id);
        break;
      case "announcement":
        await supabase.from("announcements").delete().eq("id", target_id);
        break;
      case "poll_comment":
        await supabase.from("poll_comments").delete().eq("id", target_id);
        break;
      case "chat_message":
        await supabase.from("chat_messages").delete().eq("id", target_id);
        break;
      case "profile":
        // For profiles, anonymize basic fields instead of hard delete
        await supabase
          .from("profiles")
          .update({
            full_name: "Deleted user",
            student_id: null,
          })
          .eq("id", target_id);
        break;
      default:
        // no-op
        break;
    }
  } catch (e) {
    console.error("Failed to delete original content", {
      target_type,
      target_id,
      error: (e as Error).message,
    });
  }

  // Update content_reports if provided
  if (report_id) {
    const { error: reportUpdateError } = await supabase
      .from("content_reports")
      .update({
        status: "resolved",
        action_taken: "deleted",
        moderator_profile_id,
        resolved_at: new Date().toISOString(),
        moderator_note: note ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", report_id);

    if (reportUpdateError) {
      console.error("Failed to update content_reports after delete:", reportUpdateError);
    }
  }

  // Insert audit log
  const { error: auditError } = await supabase.from("moderation_actions").insert({
    moderator_profile_id,
    action: "delete_content",
    target_type,
    target_id,
    report_id: report_id ?? null,
    metadata: {
      note: note ?? null,
    },
  });

  if (auditError) {
    console.error("Failed to insert moderation_actions (delete_content):", auditError);
  }

  return jsonResponse({ ok: true });
});

