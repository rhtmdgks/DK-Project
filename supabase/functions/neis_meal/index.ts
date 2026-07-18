// NEIS Meal API proxy. API key from env only. Optional: 24h cache via Supabase table.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const NEIS_MEAL_URL = 'https://open.neis.go.kr/hub/mealServiceDietInfo';

interface NeisMealRow {
  MLSV_YMD?: string;
  DDISH_NM?: string;
  ORPLC_INFO?: string;
  CAL_INFO?: string;
  NTR_INFO?: string;
  MLSV_FGR?: number;
  [key: string]: unknown;
}

interface NeisResponse {
  mealServiceDietInfo?: Array<{ head?: unknown[]; row?: NeisMealRow[] }>;
  RESULT?: { CODE?: string; MESSAGE?: string };
  result?: { code?: string; message?: string };
  message?: string;
  resMessage?: string;
  _raw?: string;
}

function getEnvVar(key: string): string | undefined {
  return Deno.env.get(key);
}

function parseDate(input: string | null): string | null {
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

/**
 * Look up NEIS codes for a school row. Best-effort: any failure (missing env,
 * query error, missing row, null columns) returns nulls so callers fall back
 * to the legacy env/hardcoded path.
 */
async function lookupSchoolNeisCodes(
  schoolId: string,
): Promise<{ atpt: string | null; schul: string | null }> {
  try {
    const supabaseUrl = getEnvVar('SUPABASE_URL');
    const serviceRoleKey = getEnvVar('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) return { atpt: null, schul: null };
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data, error } = await supabase
      .from('schools')
      .select('atpt_ofcdc_sc_code, sd_schul_code')
      .eq('id', schoolId)
      .maybeSingle();
    if (error || !data) return { atpt: null, schul: null };
    const atpt = typeof data.atpt_ofcdc_sc_code === 'string' && data.atpt_ofcdc_sc_code.trim() !== ''
      ? data.atpt_ofcdc_sc_code.trim()
      : null;
    const schul = typeof data.sd_schul_code === 'string' && data.sd_schul_code.trim() !== ''
      ? data.sd_schul_code.trim()
      : null;
    return { atpt, schul };
  } catch {
    return { atpt: null, schul: null };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { Allow: 'GET, POST, OPTIONS' } });
  }
  if (req.method !== 'GET' && req.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  const apiKey = getEnvVar('NEIS_API_KEY');
  if (!apiKey) {
    return jsonResponse({ error: 'server_config', message: 'NEIS API key not configured' }, 500);
  }

  const atpt = getEnvVar('NEIS_ATPT_OFCDC_SC_CODE') || 'G10';
  const schul = getEnvVar('NEIS_SD_SCHUL_CODE') || '7430030';

  const url = new URL(req.url);
  let dateParam = url.searchParams.get('date') || url.searchParams.get('MLSV_YMD');
  let schoolIdParam = url.searchParams.get('school_id');
  if (req.method === 'POST') {
    try {
      const body = await req.clone().json() as Record<string, unknown> | null;
      if (body) {
        if ((!dateParam || dateParam.trim() === '') && (body.date != null || body.MLSV_YMD != null)) {
          dateParam = String(body.date ?? body.MLSV_YMD ?? '');
        }
        if ((!schoolIdParam || schoolIdParam.trim() === '') && body.school_id != null) {
          schoolIdParam = String(body.school_id);
        }
      }
    } catch {
      // ignore
    }
  }
  const mlsvYmd = parseDate(dateParam);
  const date = mlsvYmd || parseDate(new Date().toISOString().slice(0, 10));

  // NEIS code resolution priority:
  // 1) explicit ATPT_OFCDC_SC_CODE / SD_SCHUL_CODE query params (legacy compat)
  // 2) schools table lookup via school_id (best-effort; failure falls through)
  // 3) env NEIS_ATPT_OFCDC_SC_CODE / NEIS_SD_SCHUL_CODE
  // 4) hardcoded legacy defaults ('G10' / '7430030')
  let schoolAtpt: string | null = null;
  let schoolSchul: string | null = null;
  if (schoolIdParam && schoolIdParam.trim() !== '') {
    const codes = await lookupSchoolNeisCodes(schoolIdParam.trim());
    schoolAtpt = codes.atpt;
    schoolSchul = codes.schul;
  }

  const ofcdc = url.searchParams.get('ATPT_OFCDC_SC_CODE') || schoolAtpt || atpt;
  const sdSchul = url.searchParams.get('SD_SCHUL_CODE') || schoolSchul || schul;

  if (!ofcdc || !sdSchul) {
    return jsonResponse({
      error: 'invalid_params',
      message: 'ATPT_OFCDC_SC_CODE and SD_SCHUL_CODE are required (or set via env)',
    }, 400);
  }

  const params = new URLSearchParams({
    KEY: apiKey,
    Type: 'json',
    ATPT_OFCDC_SC_CODE: ofcdc,
    SD_SCHUL_CODE: sdSchul,
    MLSV_YMD: date!,
  });

  try {
    const neisUrl = `${NEIS_MEAL_URL}?${params.toString()}`;
    const res = await fetch(neisUrl);
    const rawText = await res.text();

    let data: NeisResponse;
    try {
      data = JSON.parse(rawText) as NeisResponse;
    } catch {
      data = { _raw: rawText.slice(0, 500) };
    }

    const result = (data.mealServiceDietInfo?.[0] as Record<string, unknown> | undefined)
      ?? data.RESULT
      ?? data.result;
    const resultCode = result ? String((result as Record<string, unknown>).CODE ?? (result as Record<string, unknown>).code ?? '') : '';
    const resultMsg = result ? String((result as Record<string, unknown>).MESSAGE ?? (result as Record<string, unknown>).message ?? '') : '';

    let combinedMsg = resultMsg
      || data.message
      || data.resMessage
      || data._raw
      || '';
    if (typeof combinedMsg === 'string' && combinedMsg.trim().startsWith('<')) {
      combinedMsg = `NEIS 서버 오류(HTTP ${res.status}). 인증키·교육청·학교코드를 확인하세요.`;
    }

    if (resultCode && resultCode.toUpperCase() !== 'NORMAL' && resultCode.toUpperCase() !== 'INFO-200') {
      return jsonResponse({
        error: 'neis_error',
        message: combinedMsg || 'NEIS API returned an error',
        code: resultCode,
        data,
      }, 502);
    }

    if (!res.ok) {
      return jsonResponse({
        error: 'neis_error',
        message: combinedMsg || `NEIS API HTTP ${res.status}`,
        status: res.status,
        data,
      }, 502);
    }

    const mealInfo = data.mealServiceDietInfo;
    const rows = Array.isArray(mealInfo)
      ? (mealInfo[1]?.row ?? mealInfo[0]?.row)
      : undefined;
    const list: NeisMealRow[] = Array.isArray(rows) ? rows : [];

    return jsonResponse({
      date,
      ATPT_OFCDC_SC_CODE: ofcdc,
      SD_SCHUL_CODE: sdSchul,
      meals: list,
    });
  } catch (e: unknown) {
    return jsonResponse({
      error: 'fetch_error',
      message: e instanceof Error ? e.message : 'Unknown error',
    }, 502);
  }
});
