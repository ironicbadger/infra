FROM actualbudget/actual-server:26.9.0@sha256:552beab3dec8c93d46b8b9245612d63c3f123b8a45063a474f53e229b17621d3
WORKDIR /sync
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY runner.mjs logic.mjs ./
ENTRYPOINT ["node", "/sync/runner.mjs"]
