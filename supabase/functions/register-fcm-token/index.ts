import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function parseGradeClassFromStudentId(studentId: string): { grade: number; classNumber: number } | null {
  const t = studentId.trim();
  if (!/^\d{5}$/.test(t)) return null;
  const grade = Number.parseInt(t.slice(0, 1), 10);
  const classNumber = Number.parseInt(t.slice(1, 3), 10);
  if (!Number.isInteger(grade) || grade < 1 || grade > 3) return null;
  if (!Number.isInteger(classNumber) || classNumber < 1 || classNumber > 10) return null;
  return { grade, classNumber };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { Allow: "POST, OPTIONS" } });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let body: { action?: string; token?: string; platform?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const tokenFromHeader = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
  if (!tokenFromHeader) {
    return jsonResponse({ error: "unauthorized", message: "missing bearer token" }, 401);
  }

  const authClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${tokenFromHeader}` } },
  });
  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();
  if (userError || !user) {
    return jsonResponse({ error: "unauthorized", message: "invalid bearer token" }, 401);
  }

  const supabase = createClient(url, serviceRoleKey);

  const userId = user.id;
  const action = (body.action ?? "register") as string;

  if (action === "unregister") {
    const { error } = await supabase.from("fcm_tokens").delete().eq("user_id", userId);
    if (error) {
      console.error("fcm_tokens delete error:", error);
      return jsonResponse({ error: "db_error", message: error.message }, 500);
    }
    return jsonResponse({ ok: true });
  }

  const token = body.token;
  if (typeof token !== "string" || !token.trim()) {
    return jsonResponse({ error: "invalid_params", message: "token required for register" }, 400);
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("grade,class_number,student_id,school_id")
    .eq("user_id", userId)
    .single();
  if (profileError || !profile) {
    return jsonResponse({ error: "forbidden", message: "profile not found" }, 403);
  }

  let grade = Number(profile.grade);
  let classNumber = Number(profile.class_number);
  if (!Number.isInteger(grade) || !Number.isInteger(classNumber)) {
    const parsed = parseGradeClassFromStudentId(String(profile.student_id ?? ""));
    if (!parsed) {
      return jsonResponse({ error: "invalid_profile", message: "grade/class_number unavailable" }, 400);
    }
    grade = parsed.grade;
    classNumber = parsed.classNumber;
  }

  const platform = typeof body.platform === "string" && /^(ios|android)$/i.test(body.platform.trim())
    ? body.platform.trim().toLowerCase()
    : null;

  const { error } = await supabase.from("fcm_tokens").upsert(
    {
      user_id: userId,
      token: token.trim(),
      grade,
      class_number: classNumber,
      // Multi-school: null is intentionally included; a DB trigger fills the
      // default school when null (legacy clients/profiles without school_id).
      school_id: profile.school_id ?? null,
      ...(platform ? { platform } : {}),
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id" }
  );

  if (error) {
    console.error("fcm_tokens upsert error:", error);
    return jsonResponse({ error: "db_error", message: error.message }, 500);
  }
  return jsonResponse({ ok: true });
});
