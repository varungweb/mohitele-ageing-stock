# Stage 1: Build React app
FROM node:18 AS builder

WORKDIR /app

COPY packag*.json ./
RUN npm i

COPY . .

EXPOSE 3000
CMD ["npm", "run", "dev"]
