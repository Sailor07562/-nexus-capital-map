FROM node:24-alpine

WORKDIR /app
COPY package.json ./
COPY app ./app
COPY frontend ./frontend

ENV NODE_ENV=production
ENV NEXUS_COMMAND_TOWER_HOST=0.0.0.0
ENV NEXUS_COMMAND_TOWER_PORT=8080
EXPOSE 8080

CMD ["npm", "start"]
