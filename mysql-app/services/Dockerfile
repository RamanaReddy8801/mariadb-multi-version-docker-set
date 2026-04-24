FROM node:20-alpine

RUN apk add --no-cache curl

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

ARG PORT=4000
ENV PORT=${PORT}

COPY . .

EXPOSE ${PORT}

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["node", "--max-old-space-size=2048", "app.js"]
