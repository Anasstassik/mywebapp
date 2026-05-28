FROM node:20-slim

WORKDIR /opt/mywebapp

RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./

RUN npm ci --omit=dev

COPY prisma ./prisma
RUN npx prisma generate

COPY . .

USER node

ENV PORT=5000
EXPOSE 5000

CMD ["node", "server.js"]