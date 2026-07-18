import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (_req: Request) => {
  const apiKey = Deno.env.get('NEIS_API_KEY') || '';
  const atpt = Deno.env.get('NEIS_ATPT_OFCDC_SC_CODE') || '(not set)';
  const schul = Deno.env.get('NEIS_SD_SCHUL_CODE') || '(not set)';

  const keyInfo = {
    length: apiKey.length,
    first4: apiKey.slice(0, 4),
    last4: apiKey.slice(-4),
    hasWhitespace: apiKey !== apiKey.trim(),
    hasNewline: apiKey.includes('\n') || apiKey.includes('\r'),
  };

  // Test 1: schoolInfo with the stored key
  const schoolUrl = `https://open.neis.go.kr/hub/schoolInfo?KEY=${encodeURIComponent(apiKey)}&Type=json&ATPT_OFCDC_SC_CODE=${atpt}&SD_SCHUL_CODE=${schul}`;
  let schoolResult: unknown;
  let schoolStatus = 0;
  try {
    const res = await fetch(schoolUrl);
    schoolStatus = res.status;
    const text = await res.text();
    try { schoolResult = JSON.parse(text); } catch { schoolResult = text.slice(0, 500); }
  } catch (e) {
    schoolResult = e instanceof Error ? e.message : 'fetch error';
  }

  // Test 2: mealServiceDietInfo with URLSearchParams (same as neis_meal)
  const params = new URLSearchParams({
    KEY: apiKey,
    Type: 'json',
    ATPT_OFCDC_SC_CODE: atpt === '(not set)' ? 'G10' : atpt,
    SD_SCHUL_CODE: schul === '(not set)' ? '7430030' : schul,
    MLSV_YMD: '20260217',
  });
  const mealUrl = `https://open.neis.go.kr/hub/mealServiceDietInfo?${params.toString()}`;
  let mealResult: unknown;
  let mealStatus = 0;
  let mealUrlSafe = mealUrl.replace(apiKey, '***MASKED***');
  try {
    const res = await fetch(mealUrl, { headers: { Accept: 'application/json' } });
    mealStatus = res.status;
    const text = await res.text();
    try { mealResult = JSON.parse(text); } catch { mealResult = text.slice(0, 500); }
  } catch (e) {
    mealResult = e instanceof Error ? e.message : 'fetch error';
  }

  // Test 3: same meal URL but without Accept header
  let meal3Result: unknown;
  let meal3Status = 0;
  try {
    const res = await fetch(mealUrl);
    meal3Status = res.status;
    const text = await res.text();
    try { meal3Result = JSON.parse(text); } catch { meal3Result = text.slice(0, 500); }
  } catch (e) {
    meal3Result = e instanceof Error ? e.message : 'fetch error';
  }

  return new Response(JSON.stringify({
    env: { atpt, schul, keyInfo },
    schoolInfo: { status: schoolStatus, result: schoolResult },
    mealWithAccept: { status: mealStatus, url: mealUrlSafe, result: mealResult },
    mealNoAccept: { status: meal3Status, result: meal3Result },
  }, null, 2), {
    headers: { 'Content-Type': 'application/json' },
  });
});
