# Schedule Planner Backend

This folder contains a custom Node.js backend for the Schedule Planner Flutter app.

## Run locally

```bash
npm install
npm run dev
```

The backend runs at:

- http://localhost:3000/api/health
- http://10.0.2.2:3000/api (Android emulator)

## Auth endpoints

- POST /api/auth/register
- POST /api/auth/login
- GET /api/auth/me

## Tasks endpoints

- GET /api/tasks
- POST /api/tasks
- PUT /api/tasks/:id
- DELETE /api/tasks/:id

The data is saved in the local JSON store file under `data/store.json`.
