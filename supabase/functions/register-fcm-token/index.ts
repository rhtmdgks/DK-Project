// FCM 토큰 등록: 앱에서 호출. RPC 전용 로그인 등 auth.uid()가 없을 때 사용.
// 헤더 X-FCM-Register-Secret 이 env와 일치하면 service_role로 upsert.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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

  const secret = Deno.env.get("FCM_REGISTER_SECRET");
  const headerSecret = req.headers.get("X-FCM-Register-Secret") ?? "";
  if (!secret || secret !== headerSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: { action?: string; user_id?: string; token?: string; grade?: number; class_number?: number; platform?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const action = (body.action ?? "register") as string;
  const userId = body.user_id;
  if (typeof userId !== "string" || !userId.trim()) {
    return jsonResponse({ error: "invalid_params", message: "user_id required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  if (action === "unregister") {
    const { error } = await supabase.from("fcm_tokens").delete().eq("user_id", userId.trim());
    if (error) {
      console.error("fcm_tokens delete error:", error);
      return jsonResponse({ error: "db_error", message: error.message }, 500);
    }
    return jsonResponse({ ok: true });
  }

  const token = body.token;
  const grade = Number(body.grade);
  const classNumber = Number(body.class_number);
  if (typeof token !== "string" || !token.trim()) {
    return jsonResponse({ error: "invalid_params", message: "token required for register" }, 400);
  }
  if (!Number.isInteger(grade) || grade < 1 || grade > 3 || !Number.isInteger(classNumber) || classNumber < 1 || classNumber > 10) {
    return jsonResponse({ error: "invalid_params", message: "grade(1-3) and class_number(1-10) required" }, 400);
  }

  const platform = typeof body.platform === "string" && /^(ios|android)$/i.test(body.platform.trim())
    ? body.platform.trim().toLowerCase()
    : null;

  const { error } = await supabase.from("fcm_tokens").upsert(
    {
      user_id: userId.trim(),
      token: token.trim(),
      grade,
      class_number: classNumber,
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
