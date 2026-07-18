import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const MEAL_DEPARTURE_CHANNEL_PREFIX = "meal-departure" as const;
const MEAL_DEPARTURE_EVENT = "meal-departure" as const;

type MealDepartureSchedule = {
  grade: number;
  class_number: number;
  weekday: number;
  hour: number;
  minute: number;
  school_id: string | null;
};

type MealDeparturePayload = {
  message: string;
  body: string;
  grade: number;
  class_number: number;
  at: string;
  school_id?: string;
};

function getKoreaNow() {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = formatter.formatToParts(now);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  const y = get("year");
  const m = get("month") - 1;
  const d = get("day");
  const h = get("hour");
  const min = get("minute");
  const s = get("second");
  return new Date(y, m, d, h, min, s);
}

function getKoreaWeekday(now: Date): number {
  const day = now.getDay(); // 0=일,1=월,...6=토
  if (day === 0) return 7; // 일요일 → 7 (사용 안 함)
  return day; // 1~6 (월~토)
}

Deno.serve(async (_req) => {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return new Response(
      JSON.stringify({ ok: false, error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(url, serviceKey);

  const nowKst = getKoreaNow();
  const weekday = getKoreaWeekday(nowKst);
  const hour = nowKst.getHours();
  const minute = nowKst.getMinutes();

  // 월~금만 동작
  if (weekday < 1 || weekday > 5) {
    return new Response(JSON.stringify({ ok: true, skipped: true, reason: "weekend" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data, error } = await supabase
    .from("meal_departure_schedules")
    .select("grade,class_number,weekday,hour,minute,school_id")
    .eq("weekday", weekday)
    .eq("hour", hour)
    .eq("minute", minute);

  if (error) {
    return new Response(
      JSON.stringify({ ok: false, error: `schedule query failed: ${error.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const rows = (data ?? []) as MealDepartureSchedule[];
  if (!rows.length) {
    return new Response(JSON.stringify({ ok: true, dispatched: 0 }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const results: { grade: number; class_number: number; ok: boolean; error?: string }[] = [];

  for (const row of rows) {
    // Multi-school: schedules may carry a school_id. When present it is passed
    // through to send-meal-push so tokens are filtered per school; when null
    // the legacy (grade, class_number)-only behavior is preserved.
    const schoolId = typeof row.school_id === "string" && row.school_id.trim() !== ""
      ? row.school_id.trim()
      : null;

    const message = "급식 출발 알림";
    const body = `${row.grade}학년 ${row.class_number}반 급식이 출발했습니다.`;
    const payload: MealDeparturePayload = {
      message,
      body,
      grade: row.grade,
      class_number: row.class_number,
      at: new Date().toISOString(),
      ...(schoolId ? { school_id: schoolId } : {}),
    };

    // 1) Realtime Broadcast (앱이 켜져 있는 학생용)
    try {
      const channelName = `${MEAL_DEPARTURE_CHANNEL_PREFIX}:${row.grade}:${row.class_number}`;
      const channel = supabase.channel(channelName, { config: { broadcast: { ack: true } } });
      await channel.subscribe();
      await channel.send({
        type: "broadcast",
        event: MEAL_DEPARTURE_EVENT,
        payload,
      });
      supabase.removeChannel(channel);
    } catch (e) {
      results.push({ grade: row.grade, class_number: row.class_number, ok: false, error: String(e) });
      continue;
    }

    // 2) FCM Push (앱이 꺼져 있어도 수신)
    try {
      const fnUrl = `${url.replace(/\/$/, "")}/functions/v1/send-meal-push`;
      const res = await fetch(fnUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          grade: row.grade,
          class_number: row.class_number,
          message,
          body,
          ...(schoolId ? { school_id: schoolId } : {}),
        }),
      });

      if (!res.ok) {
        const text = await res.text();
        results.push({
          grade: row.grade,
          class_number: row.class_number,
          ok: false,
          error: `send-meal-push failed: ${res.status} ${text}`,
        });
        continue;
      }

      results.push({ grade: row.grade, class_number: row.class_number, ok: true });
    } catch (e) {
      results.push({ grade: row.grade, class_number: row.class_number, ok: false, error: String(e) });
    }
  }

  const dispatched = results.filter((r) => r.ok).length;

  return new Response(JSON.stringify({ ok: true, dispatched, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
