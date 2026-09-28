const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const DATA_DIR = path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'store.json');

const defaultStore = {
  users: [],
  tasks: [],
};

function ensureStore() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }

  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(defaultStore, null, 2));
  }
}

function readStore() {
  ensureStore();
  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  try {
    return JSON.parse(raw);
  } catch {
    fs.writeFileSync(DATA_FILE, JSON.stringify(defaultStore, null, 2));
    return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  }
}

function writeStore(store) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(store, null, 2));
}

function generateToken() {
  return `token_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function createUserPayload(user) {
  const { password, ...safeUser } = user;
  return safeUser;
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.replace('Bearer ', '').trim() : '';

  if (!token) {
    return res.status(401).json({ message: 'Token tidak valid atau tidak ada.' });
  }

  const store = readStore();
  const user = store.users.find((item) => item.token === token);

  if (!user) {
    return res.status(401).json({ message: 'User tidak ditemukan.' });
  }

  req.user = user;
  next();
}

app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Schedule Planner backend is running.' });
});

app.post('/api/auth/register', (req, res) => {
  const { name, email, password } = req.body || {};

  if (!name || !email || !password) {
    return res.status(400).json({ message: 'Nama, email, dan password wajib diisi.' });
  }

  const store = readStore();
  const emailExists = store.users.some(
    (user) => user.email.toLowerCase() === String(email).toLowerCase(),
  );

  if (emailExists) {
    return res.status(409).json({ message: 'Email sudah terdaftar.' });
  }

  const user = {
    id: String(Date.now()),
    name: String(name).trim(),
    email: String(email).trim(),
    password: String(password),
    username: String(name).trim().toLowerCase().replace(/[^a-z0-9]/g, '') || 'planner',
    token: generateToken(),
    createdAt: new Date().toISOString(),
  };

  store.users.push(user);
  writeStore(store);

  return res.status(201).json({
    message: 'Registrasi berhasil.',
    token: user.token,
    user: createUserPayload(user),
  });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password) {
    return res.status(400).json({ message: 'Email dan password wajib diisi.' });
  }

  const store = readStore();
  const user = store.users.find(
    (item) =>
      item.email.toLowerCase() === String(email).toLowerCase() &&
      item.password === String(password),
  );

  if (!user) {
    return res.status(401).json({ message: 'Email atau password salah.' });
  }

  user.token = user.token || generateToken();
  writeStore(store);

  return res.json({
    message: 'Login berhasil.',
    token: user.token,
    user: createUserPayload(user),
  });
});

app.get('/api/auth/me', authMiddleware, (req, res) => {
  return res.json({
    user: createUserPayload(req.user),
  });
});

app.get('/api/tasks', authMiddleware, (req, res) => {
  const store = readStore();
  const tasks = store.tasks.filter((task) => task.userId === req.user.id);
  return res.json({ tasks });
});

app.post('/api/tasks', authMiddleware, (req, res) => {
  const { title, description, dueDate, dueTime, priority, completed } = req.body || {};

  if (!title) {
    return res.status(400).json({ message: 'Judul tugas wajib diisi.' });
  }

  const store = readStore();
  const task = {
    id: String(Date.now()),
    userId: req.user.id,
    title: String(title).trim(),
    description: description ? String(description).trim() : '',
    dueDate: dueDate || null,
    dueTime: dueTime || null,
    priority: priority || 'Medium',
    completed: Boolean(completed),
    createdAt: new Date().toISOString(),
  };

  store.tasks.push(task);
  writeStore(store);

  return res.status(201).json({ message: 'Tugas berhasil ditambahkan.', task });
});

app.put('/api/tasks/:id', authMiddleware, (req, res) => {
  const { id } = req.params;
  const store = readStore();
  const taskIndex = store.tasks.findIndex(
    (task) => task.id === id && task.userId === req.user.id,
  );

  if (taskIndex === -1) {
    return res.status(404).json({ message: 'Tugas tidak ditemukan.' });
  }

  const currentTask = store.tasks[taskIndex];
  store.tasks[taskIndex] = {
    ...currentTask,
    ...req.body,
    updatedAt: new Date().toISOString(),
  };

  writeStore(store);
  return res.json({ message: 'Tugas berhasil diperbarui.', task: store.tasks[taskIndex] });
});

app.delete('/api/tasks/:id', authMiddleware, (req, res) => {
  const { id } = req.params;
  const store = readStore();
  const beforeLength = store.tasks.length;
  store.tasks = store.tasks.filter(
    (task) => !(task.id === id && task.userId === req.user.id),
  );

  if (store.tasks.length === beforeLength) {
    return res.status(404).json({ message: 'Tugas tidak ditemukan.' });
  }

  writeStore(store);
  return res.json({ message: 'Tugas berhasil dihapus.' });
});

app.listen(PORT, () => {
  console.log(`Schedule Planner backend running on http://localhost:${PORT}`);
});
