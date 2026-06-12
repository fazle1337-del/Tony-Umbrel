const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = 3001;

// ─── DB ────────────────────────────────────────────────────────────────────────
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS foods (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      cat TEXT NOT NULL,
      unit TEXT NOT NULL DEFAULT 'g',
      unit_name TEXT NOT NULL DEFAULT '1g',
      protein NUMERIC NOT NULL DEFAULT 0,
      carbs NUMERIC NOT NULL DEFAULT 0,
      fat NUMERIC NOT NULL DEFAULT 0,
      state TEXT NOT NULL DEFAULT 'Cooked',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS log_entries (
      id TEXT PRIMARY KEY,
      entry_date DATE NOT NULL,
      food_id TEXT,
      food_name TEXT NOT NULL,
      protein_per_unit NUMERIC NOT NULL DEFAULT 0,
      carbs_per_unit NUMERIC NOT NULL DEFAULT 0,
      fat_per_unit NUMERIC NOT NULL DEFAULT 0,
      unit TEXT NOT NULL DEFAULT 'g',
      unit_name TEXT NOT NULL DEFAULT '1g',
      amount NUMERIC NOT NULL,
      meal TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS log_entries_date_idx ON log_entries(entry_date);
  `);

  // Seed default foods if table is empty
  const { rows } = await pool.query('SELECT COUNT(*) FROM foods');
  if (parseInt(rows[0].count) === 0) {
    console.log('Seeding default foods...');
    await seedFoods();
  }

  console.log('Database ready');
}

// ─── MIDDLEWARE ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// Simple API key check — swap for JWT when adding multi-user
app.use((req, res, next) => {
  // Allow health check without auth
  if (req.path === '/health') return next();
  const key = req.headers['x-api-key'];
  if (key !== process.env.API_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

// ─── HEALTH ────────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ─── FOODS ────────────────────────────────────────────────────────────────────
app.get('/api/foods', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM foods ORDER BY name ASC');
    res.json(rows.map(dbFoodToApi));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/foods', async (req, res) => {
  const { id, name, cat, unit, unitName, p, c, f, state } = req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO foods (id, name, cat, unit, unit_name, protein, carbs, fat, state)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT (id) DO UPDATE SET
         name=$2, cat=$3, unit=$4, unit_name=$5, protein=$6, carbs=$7, fat=$8, state=$9
       RETURNING *`,
      [id, name, cat, unit, unitName, p, c, f, state]
    );
    res.json(dbFoodToApi(rows[0]));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/foods/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM foods WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Replace entire foods table with imported rows
app.post('/api/foods/import', async (req, res) => {
  const { foods } = req.body;
  if (!Array.isArray(foods)) {
    return res.status(400).json({ error: 'foods must be an array' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('TRUNCATE foods');
    for (const food of foods) {
      const { name, cat, unit, unitName, p, c, f, state } = food;
      if (!name) continue;
      const id = 'f_' + Math.random().toString(36).slice(2, 10);
      await client.query(
        `INSERT INTO foods (id, name, cat, unit, unit_name, protein, carbs, fat, state)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [id, name, cat || 'other', unit || 'g', unitName || '1g', p || 0, c || 0, f || 0, state || 'Cooked']
      );
    }
    await client.query('COMMIT');
    const { rows } = await pool.query('SELECT * FROM foods ORDER BY name ASC');
    res.json({ imported: rows.length, foods: rows.map(dbFoodToApi) });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});

// ─── LOG ENTRIES ───────────────────────────────────────────────────────────────
app.get('/api/log', async (req, res) => {
  const { from, to } = req.query;
  try {
    let query = 'SELECT * FROM log_entries';
    const params = [];
    if (from && to) {
      query += ' WHERE entry_date >= $1 AND entry_date <= $2';
      params.push(from, to);
    } else if (from) {
      query += ' WHERE entry_date >= $1';
      params.push(from);
    }
    query += ' ORDER BY entry_date ASC, created_at ASC';
    const { rows } = await pool.query(query, params);
    // Group by date
    const grouped = {};
    rows.forEach(r => {
      const d = r.entry_date.toISOString().slice(0, 10);
      if (!grouped[d]) grouped[d] = [];
      grouped[d].push(dbEntryToApi(r));
    });
    res.json(grouped);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/log/:date', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM log_entries WHERE entry_date=$1 ORDER BY created_at ASC',
      [req.params.date]
    );
    res.json(rows.map(dbEntryToApi));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/log', async (req, res) => {
  const { id, date, foodId, foodName, p, c, fat, unit, unitName, amount, meal } = req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO log_entries
         (id, entry_date, food_id, food_name, protein_per_unit, carbs_per_unit, fat_per_unit, unit, unit_name, amount, meal)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING *`,
      [id, date, foodId, foodName, p, c, fat, unit, unitName, amount, meal || null]
    );
    res.json(dbEntryToApi(rows[0]));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/log/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM log_entries WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── HELPERS ───────────────────────────────────────────────────────────────────
function dbFoodToApi(r) {
  return {
    id: r.id, name: r.name, cat: r.cat,
    unit: r.unit, unitName: r.unit_name,
    p: parseFloat(r.protein), c: parseFloat(r.carbs), f: parseFloat(r.fat),
    state: r.state
  };
}

function dbEntryToApi(r) {
  return {
    id: r.id,
    date: r.entry_date.toISOString().slice(0, 10),
    foodId: r.food_id,
    foodName: r.food_name,
    p: parseFloat(r.protein_per_unit),
    c: parseFloat(r.carbs_per_unit),
    fat: parseFloat(r.fat_per_unit),
    unit: r.unit,
    unitName: r.unit_name,
    amount: parseFloat(r.amount),
    meal: r.meal || ''
  };
}

// ─── SEED DATA ─────────────────────────────────────────────────────────────────
async function seedFoods() {
  const foods = [
    {id:'f1',name:'Lean beef mince 5% M&S',cat:'beef',unit:'g',unitName:'1g',p:0.22,c:0,f:0.052,state:'Raw'},
    {id:'f2',name:'Kings beef jerky',cat:'beef',unit:'fixed',unitName:'Per Pack',p:21,c:12.9,f:1.7,state:'As is'},
    {id:'f3',name:'Whey USN Blue Lab',cat:'dairy',unit:'fixed',unitName:'Per Scoop',p:26,c:2,f:2,state:'As is'},
    {id:'f4',name:'Butter',cat:'dairy',unit:'g',unitName:'1g',p:0,c:0,f:0.82,state:'As is'},
    {id:'f5',name:'Chicken breast',cat:'poultry',unit:'g',unitName:'1g',p:0.31,c:0,f:0.036,state:'Cooked'},
    {id:'f6',name:'Chicken thigh',cat:'poultry',unit:'g',unitName:'1g',p:0.26,c:0,f:0.108,state:'Cooked'},
    {id:'f7',name:'Chicken drumstick',cat:'poultry',unit:'g',unitName:'1g',p:0.28,c:0,f:0.057,state:'Cooked'},
    {id:'f8',name:'Chicken wing',cat:'poultry',unit:'g',unitName:'1g',p:0.264,c:0,f:0.117,state:'Cooked'},
    {id:'f9',name:'Turkey breast',cat:'poultry',unit:'g',unitName:'1g',p:0.295,c:0,f:0.065,state:'Cooked'},
    {id:'f10',name:'Sirloin steak',cat:'beef',unit:'g',unitName:'1g',p:0.27,c:0,f:0.115,state:'Cooked'},
    {id:'f11',name:'Fillet steak / tenderloin',cat:'beef',unit:'g',unitName:'1g',p:0.279,c:0,f:0.108,state:'Cooked'},
    {id:'f12',name:'Ribeye steak',cat:'beef',unit:'g',unitName:'1g',p:0.241,c:0,f:0.201,state:'Cooked'},
    {id:'f13',name:'T-bone steak',cat:'beef',unit:'g',unitName:'1g',p:0.258,c:0,f:0.133,state:'Cooked'},
    {id:'f14',name:'Brisket',cat:'beef',unit:'g',unitName:'1g',p:0.28,c:0,f:0.156,state:'Cooked'},
    {id:'f15',name:'Pork tenderloin',cat:'pork',unit:'g',unitName:'1g',p:0.262,c:0,f:0.038,state:'Cooked'},
    {id:'f16',name:'Pork chop',cat:'pork',unit:'g',unitName:'1g',p:0.265,c:0,f:0.105,state:'Cooked'},
    {id:'f17',name:'Pork belly',cat:'pork',unit:'g',unitName:'1g',p:0.091,c:0,f:0.53,state:'Cooked'},
    {id:'f18',name:'Bacon',cat:'pork',unit:'g',unitName:'1g',p:0.12,c:0.001,f:0.515,state:'Cooked'},
    {id:'f19',name:'Ham',cat:'pork',unit:'g',unitName:'1g',p:0.209,c:0.017,f:0.054,state:'Cooked'},
    {id:'f20',name:'Salmon',cat:'fish',unit:'g',unitName:'1g',p:0.228,c:0,f:0.009,state:'Cooked'},
    {id:'f21',name:'Cod',cat:'fish',unit:'g',unitName:'1g',p:0.259,c:0,f:0.01,state:'Cooked'},
    {id:'f22',name:'Tuna (canned in water)',cat:'fish',unit:'g',unitName:'1g',p:0.262,c:0,f:0.027,state:'Cooked'},
    {id:'f23',name:'Mackerel',cat:'fish',unit:'g',unitName:'1g',p:0.239,c:0,f:0.178,state:'Cooked'},
    {id:'f24',name:'Prawns / shrimp',cat:'fish',unit:'g',unitName:'1g',p:0.209,c:0,f:0.011,state:'Cooked'},
    {id:'f25',name:'Whole egg',cat:'eggs',unit:'g',unitName:'1g',p:0.126,c:0.007,f:0.099,state:'Raw'},
    {id:'f26',name:'Egg white',cat:'eggs',unit:'g',unitName:'1g',p:0.109,c:0.007,f:0.002,state:'Raw'},
    {id:'f27',name:'Egg yolk',cat:'eggs',unit:'g',unitName:'1g',p:0.158,c:0.036,f:0.267,state:'Raw'},
    {id:'f28',name:'Whole milk',cat:'dairy',unit:'g',unitName:'1g',p:0.032,c:0.047,f:0.034,state:'As is'},
    {id:'f29',name:'Greek yoghurt (full fat)',cat:'dairy',unit:'g',unitName:'1g',p:0.09,c:0.038,f:0.05,state:'As is'},
    {id:'f30',name:'Cheddar cheese',cat:'dairy',unit:'g',unitName:'1g',p:0.248,c:0.013,f:0.331,state:'As is'},
    {id:'f31',name:'Cottage cheese',cat:'dairy',unit:'g',unitName:'1g',p:0.112,c:0.031,f:0.043,state:'As is'},
    {id:'f32',name:'White rice',cat:'grains',unit:'g',unitName:'1g',p:0.027,c:0.283,f:0.003,state:'Cooked'},
    {id:'f33',name:'Brown rice',cat:'grains',unit:'g',unitName:'1g',p:0.026,c:0.23,f:0.009,state:'Cooked'},
    {id:'f34',name:'White bread',cat:'grains',unit:'g',unitName:'1g',p:0.09,c:0.49,f:0.032,state:'As is'},
    {id:'f35',name:'Oats',cat:'grains',unit:'fixed',unitName:'Per Scoop',p:1,c:21,f:3,state:'As is'},
    {id:'f36',name:'Sausage',cat:'pork',unit:'g',unitName:'1g',p:0.11,c:0.03,f:0.25,state:'Cooked'},
    {id:'f37',name:'Mince (beef)',cat:'beef',unit:'g',unitName:'1g',p:0.20,c:0,f:0.15,state:'Cooked'},
    {id:'f38',name:'Wagyu burger mince',cat:'beef',unit:'g',unitName:'1g',p:0.139,c:0,f:0.339,state:'Cooked'},
    {id:'f39',name:'Billtong',cat:'beef',unit:'g',unitName:'1g',p:0.40,c:0.02,f:0.055,state:'As is'},
    {id:'f40',name:'Lean mince',cat:'beef',unit:'g',unitName:'1g',p:0.22,c:0,f:0.08,state:'Cooked'},
    {id:'f41',name:'Rice cakes',cat:'grains',unit:'g',unitName:'1g',p:0.07,c:0.81,f:0.01,state:'As is'},
    {id:'f42',name:'Carb-x',cat:'other',unit:'fixed',unitName:'Per Scoop',p:0,c:24,f:0,state:'As is'},
    {id:'f43',name:'Sweets',cat:'other',unit:'g',unitName:'1g',p:0,c:0.9,f:0,state:'As is'},
    {id:'f44',name:'Rocky bar',cat:'other',unit:'g',unitName:'1g',p:0.04,c:0.62,f:0.14,state:'As is'},
    {id:'f45',name:'Chocolate rice cakes',cat:'grains',unit:'g',unitName:'1g',p:0.05,c:0.77,f:0.06,state:'As is'},
    {id:'f46',name:'Buldak noodles',cat:'grains',unit:'g',unitName:'1g',p:0.08,c:0.44,f:0.12,state:'As is'},
  ];
  for (const food of foods) {
    await pool.query(
      `INSERT INTO foods (id,name,cat,unit,unit_name,protein,carbs,fat,state)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT DO NOTHING`,
      [food.id, food.name, food.cat, food.unit, food.unitName, food.p, food.c, food.f, food.state]
    );
  }
}

// ─── START ─────────────────────────────────────────────────────────────────────
initDB()
  .then(() => app.listen(PORT, () => console.log(`API running on :${PORT}`)))
  .catch(e => { console.error('DB init failed:', e); process.exit(1); });
