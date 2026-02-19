// NEIS Academic Calendar (SchoolSchedule) proxy. API key from env only.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const NEIS_SCHEDULE_URL = 'https://open.neis.go.kr/hub/SchoolSchedule';

interface NeisScheduleRow {
  AA_YMD?: string;
  EVENT_NM?: string;
  EVENT_CNTNT?: string;
  SBTR_DD_SC_NM?: string;
  [key: string]: unknown;
}

interface NeisScheduleResponse {
  SchoolSchedule?: Array<{ head?: unknown[]; row?: NeisScheduleRow[] }>;
  RESULT?: { CODE?: string; MESSAGE?: string };
  [key: string]: unknown;
}

function getEnvVar(key: string): string | undefined {
  return Deno.env.get(key);
}

function parseYmd(input: string | null): string | null {
  if (!input || typeof input !== 'string') return null;
  const trimmed = input.trim();
  if (/^\d{8}$/.test(trimmed)) return trimmed;
  const d = new Date(trimmed);
  if (Number.isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { Allow: 'GET, OPTIONS' } });
  }
  if (req.method !== 'GET') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  const apiKey = getEnvVar('NEIS_API_KEY');
  if (!apiKey) {
    return jsonResponse({ error: 'server_config', message: 'NEIS API key not configured' }, 500);
  }

  const atpt = getEnvVar('NEIS_ATPT_OFCDC_SC_CODE') || 'G10';
  const schul = getEnvVar('NEIS_SD_SCHUL_CODE') || '7430030';

  const url = new URL(req.url);
  const fromParam = url.searchParams.get('from') || url.searchParams.get('AA_FROM_YMD');
  const toParam = url.searchParams.get('to') || url.searchParams.get('AA_TO_YMD');
  let fromYmd = parseYmd(fromParam);
  let toYmd = parseYmd(toParam);

  const now = new Date();
  const currentYear = now.getFullYear();
  if (!fromYmd) {
    fromYmd = `${currentYear}0301`;
  }
  if (!toYmd) {
    toYmd = `${currentYear}1231`;
  }
  if (fromYmd > toYmd) {
    return jsonResponse({ error: 'invalid_params', message: 'from must be <= to' }, 400);
  }

  const ofcdc = url.searchParams.get('ATPT_OFCDC_SC_CODE') || atpt;
  const sdSchul = url.searchParams.get('SD_SCHUL_CODE') || schul;

  if (!ofcdc || !sdSchul) {
    return jsonResponse({
      error: 'invalid_params',
      message: 'ATPT_OFCDC_SC_CODE and SD_SCHUL_CODE are required (or set via env)',
    }, 400);
  }

  const pIndex = Math.max(1, parseInt(url.searchParams.get('pIndex') || '1', 10));
  const pSize = Math.min(1000, Math.max(1, parseInt(url.searchParams.get('pSize') || '100', 10)));

  const params = new URLSearchParams({
    KEY: apiKey,
    Type: 'json',
    ATPT_OFCDC_SC_CODE: ofcdc,
    SD_SCHUL_CODE: sdSchul,
    AA_FROM_YMD: fromYmd,
    AA_TO_YMD: toYmd,
    pIndex: String(pIndex),
    pSize: String(pSize),
  });

  try {
    const res = await fetch(`${NEIS_SCHEDULE_URL}?${params.toString()}`);

    let data: NeisScheduleResponse;
    try {
      data = (await res.json()) as NeisScheduleResponse;
    } catch {
      data = {};
    }

    if (!res.ok) {
      return jsonResponse({
        error: 'neis_error',
        message: 'NEIS API request failed',
        status: res.status,
        data,
      }, 502);
    }

    const scheduleInfo = data.SchoolSchedule;
    const rows = Array.isArray(scheduleInfo)
      ? (scheduleInfo[1]?.row ?? scheduleInfo[0]?.row)
      : undefined;
    const list: NeisScheduleRow[] = Array.isArray(rows) ? rows : [];

    return jsonResponse({
      AA_FROM_YMD: fromYmd,
      AA_TO_YMD: toYmd,
      ATPT_OFCDC_SC_CODE: ofcdc,
      SD_SCHUL_CODE: sdSchul,
      schedule: list,
    });
  } catch (e: unknown) {
    return jsonResponse({
      error: 'fetch_error',
      message: e instanceof Error ? e.message : 'Unknown error',
    }, 502);
  }
});
