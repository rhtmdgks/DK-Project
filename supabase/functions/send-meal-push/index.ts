// 급식 출발 푸시: 학년·반에 해당하는 FCM 토큰에 푸시 전송 (앱이 꺼져 있어도 수신)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
} as const;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

async function getFcmAccessToken(): Promise<string | null> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw || raw.trim() === "") return null;
  try {
    const token = await getToken(raw, { scope: [FCM_SCOPE] });
    return token?.access_token ?? null;
  } catch (e) {
    console.error("FCM token error:", e);
    return null;
  }
}

async function sendFcm(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string
): Promise<boolean> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        android: {
          priority: "high",
          notification: { channel_id: "meal_notification", priority: "high" },
        },
      },
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    console.error("FCM send failed:", res.status, t);
    return false;
  }
  return true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        Allow: "POST, OPTIONS",
        ...CORS_HEADERS,
      },
    });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson || serviceAccountJson.trim() === "") {
    return jsonResponse(
      { error: "server_config", message: "FCM_SERVICE_ACCOUNT_JSON must be set in Edge Function secrets" },
      500
    );
  }
  let projectId: string;
  try {
    const sa = JSON.parse(serviceAccountJson) as { project_id?: string };
    projectId = sa.project_id ?? Deno.env.get("FCM_PROJECT_ID") ?? "";
  } catch {
    projectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
  }
  if (!projectId) {
    return jsonResponse(
      { error: "server_config", message: "FCM_PROJECT_ID or project_id in FCM_SERVICE_ACCOUNT_JSON required" },
      500
    );
  }

  let body: { grade?: number; class_number?: number; message?: string; body?: string; school_id?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const grade = Number(body.grade);
  const classNumber = Number(body.class_number);
  if (!Number.isInteger(grade) || grade < 1 || grade > 3 || !Number.isInteger(classNumber) || classNumber < 1 || classNumber > 10) {
    return jsonResponse({ error: "invalid_params", message: "grade(1-3) and class_number(1-10) required" }, 400);
  }

  const title = typeof body.message === "string" && body.message.trim() !== "" ? body.message.trim() : "급식 출발 알림";
  const notificationBody = typeof body.body === "string" && body.body.trim() !== "" ? body.body.trim() : `${grade}학년 ${classNumber}반 급식이 출발했습니다.`;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Multi-school: filter by school_id only when provided (legacy callers omit it).
  const schoolId = typeof body.school_id === "string" && body.school_id.trim() !== ""
    ? body.school_id.trim()
    : null;

  let tokenQuery = supabase
    .from("fcm_tokens")
    .select("token")
    .eq("grade", grade)
    .eq("class_number", classNumber);
  if (schoolId) {
    tokenQuery = tokenQuery.eq("school_id", schoolId);
  }

  const { data: rows, error } = await tokenQuery;

  if (error) {
    console.error("fcm_tokens select error:", error);
    return jsonResponse({ error: "db_error", message: error.message }, 500);
  }

  const tokens = (rows ?? []).map((r: { token: string }) => r.token).filter(Boolean);
  if (tokens.length === 0) {
    return jsonResponse({ ok: true, sent: 0, message: "no_tokens" });
  }

  const accessToken = await getFcmAccessToken();
  if (!accessToken) {
    return jsonResponse({ error: "fcm_auth_failed", message: "Could not get FCM access token" }, 500);
  }

  let sent = 0;
  for (const token of tokens) {
    const ok = await sendFcm(accessToken, projectId, token, title, notificationBody);
    if (ok) sent++;
  }

  return jsonResponse({ ok: true, sent, total: tokens.length });
});
