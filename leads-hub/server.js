const express = require('express');
const os = require('os');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Stockage en mémoire (une base PostgreSQL pourra être branchée plus tard)
const leads = [];

// Santé du service — utile pour les sondes ACI/ACA
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'leads-hub',
    version: '1.0.0',
    host: os.hostname(),
    uptime_s: Math.round(process.uptime()),
    time: new Date().toISOString()
  });
});

// Lister les leads
app.get('/api/leads', (req, res) => res.json(leads));

// Ajouter un lead
app.post('/api/leads', (req, res) => {
  const { name, email } = req.body || {};
  if (!name || !email) {
    return res.status(400).json({ error: 'Les champs "name" et "email" sont requis.' });
  }
  const lead = { id: leads.length + 1, name, email, at: new Date().toISOString() };
  leads.push(lead);
  res.status(201).json(lead);
});

app.listen(PORT, () => console.log(`leads-hub écoute sur le port ${PORT} (host: ${os.hostname()})`));
