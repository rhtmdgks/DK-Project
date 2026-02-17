/**
 * School Official App — Bulk User Seed Script
 * Uses Supabase service role. Idempotent: skips existing users.
 * Run: node scripts/seed.js [path/to/students.csv]
 * Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (또는 scripts/.env)
 */

const fs = require('fs');
const path = require('path');

// scripts/.env 또는 프로젝트 루트 .env 로드 (dotenv 있으면)
try {
  const dotenv = require('dotenv');
  const scriptDir = path.resolve(__dirname);
  dotenv.config({ path: path.join(scriptDir, '.env') });
  dotenv.config({ path: path.join(scriptDir, '..', '.env') });
} catch (_) {}

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DEFAULT_PASSWORD = '12345678';
const EMAIL_SUFFIX = '@school.local';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function emailFromStudentId(studentId) {
  return `${String(studentId).trim()}${EMAIL_SUFFIX}`;
}

/**
 * Idempotent: create user if not exists, then upsert profile.
 */
async function ensureUserAndProfile({ student_id, full_name, role = 'student' }) {
  const email = emailFromStudentId(student_id);
  const { data: existingUsers } = await supabase.auth.admin.listUsers();
  const existing = existingUsers?.users?.find((u) => u.email === email);
  let userId;
  if (existing) {
    userId = existing.id;
    console.log(`Skip existing user: ${email}`);
  } else {
    const { data: created, error: createError } = await supabase.auth.admin.createUser({
      email,
      password: DEFAULT_PASSWORD,
      email_confirm: true,
    });
    if (createError) {
      console.error(`Create user failed ${email}:`, createError.message);
      return { ok: false, error: createError.message };
    }
    userId = created.user.id;
    console.log(`Created user: ${email}`);
  }

  const { data: profileRows, error: profileSelectError } = await supabase
    .from('profiles')
    .select('id')
    .eq('user_id', userId)
    .limit(1);

  if (profileSelectError) {
    console.error(`Profile select error ${email}:`, profileSelectError.message);
    return { ok: false, error: profileSelectError.message };
  }

  const payload = {
    user_id: userId,
    student_id: String(student_id).trim(),
    full_name: full_name || null,
    role,
    must_change_password: true,
  };

  if (profileRows?.length) {
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        full_name: payload.full_name,
        role: payload.role,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);
    if (updateError) {
      console.error(`Profile update error ${email}:`, updateError.message);
      return { ok: false, error: updateError.message };
    }
    console.log(`Updated profile: ${email}`);
  } else {
    const { error: insertError } = await supabase.from('profiles').insert(payload);
    if (insertError) {
      console.error(`Profile insert error ${email}:`, insertError.message);
      return { ok: false, error: insertError.message };
    }
    console.log(`Inserted profile: ${email}`);
  }
  return { ok: true, userId };
}

/**
 * Parse CSV line (simple: no quoted commas).
 */
function parseCsvLine(line) {
  return line.split(',').map((s) => s.trim());
}

/**
 * Load CSV: expected header student_id, full_name [, role]
 */
function loadCsv(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split(/\r?\n/).filter((l) => l.trim());
  if (lines.length < 2) return [];
  const header = parseCsvLine(lines[0]);
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const values = parseCsvLine(lines[i]);
    const row = {};
    header.forEach((h, j) => (row[h] = values[j] ?? ''));
    rows.push(row);
  }
  return rows;
}

async function seedCouncil() {
  const councilStudentId = 'council';
  return ensureUserAndProfile({
    student_id: councilStudentId,
    full_name: 'Student Council',
    role: 'council',
  });
}

async function main() {
  console.log('Seed script started.');

  // 1) Seed council account
  await seedCouncil();

  // 2) Bulk from CSV if provided
  const csvPath = process.argv[2];
  if (csvPath) {
    const resolved = path.resolve(process.cwd(), csvPath);
    if (!fs.existsSync(resolved)) {
      console.error('CSV file not found:', resolved);
      process.exit(1);
    }
    const rows = loadCsv(resolved);
    if (!rows.length) {
      console.log('No data rows in CSV.');
    } else {
      for (const row of rows) {
        const student_id = row.student_id || row.studentId;
        if (!student_id) {
          console.warn('Skip row missing student_id:', row);
          continue;
        }
        await ensureUserAndProfile({
          student_id,
          full_name: row.full_name || row.fullName || null,
          role: row.role || 'student',
        });
      }
    }
  } else {
    // 3) Default: 초기 계정 10101 / 12345678
    const defaults = [
      { student_id: '10101', full_name: '초기 계정', role: 'student' },
    ];
    for (const row of defaults) {
      await ensureUserAndProfile(row);
    }
  }

  console.log('Seed script finished.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
