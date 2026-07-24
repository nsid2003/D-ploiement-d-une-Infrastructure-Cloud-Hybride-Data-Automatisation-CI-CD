# Image légère basée sur Node 20 Alpine
FROM node:20-alpine

# Répertoire de travail dans le conteneur
WORKDIR /app

# Installer les dépendances (couche mise en cache tant que package*.json ne change pas)
COPY package*.json ./
RUN npm install --omit=dev

# Copier le reste du code applicatif
COPY . .

# Le service écoute sur ce port (ACI/ACA le mapperont)
ENV PORT=3000
EXPOSE 3000

# Commande de démarrage
CMD ["node", "server.js"]
