# 紫微斗数排盘引擎 —— 生产镜像
# 三阶段构建：deps(装依赖) → builder(编译) → runner(运行时，非 root)
# 基础镜像固定到具体小版本，避免 latest 漂移导致的不可复现构建
# 只用标准 Dockerfile 指令，不引入外部 syntax 前端，减少构建期网络依赖

ARG NODE_VERSION=22.22.2

# ───────────────────────── Stage 1: deps ─────────────────────────
FROM node:${NODE_VERSION}-alpine AS deps
WORKDIR /app

# sharp 在 alpine 上需要 glibc 兼容层（Next 图片优化依赖）
RUN apk add --no-cache libc6-compat

# 注：.npmrc 里的 legacy-peer-deps=true 是必须的，React 19 + @types/react 18 的
# peer 依赖冲突没有它 npm ci 会直接失败
COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund

# ───────────────────────── Stage 2: builder ─────────────────────────
FROM node:${NODE_VERSION}-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# NEXT_PUBLIC_SITE_URL 必须在【构建期】传入：sitemap.xml / robots.txt / metadataBase
# 都是静态预渲染产物（build 时求值 lib/site.ts 的模块顶层常量），
# 运行时再改环境变量不会生效。改域名 = 重新构建镜像。
ARG NEXT_PUBLIC_SITE_URL=http://localhost:3000
ENV NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}

COPY --from=deps /app/node_modules ./node_modules
COPY . .
# 用 standalone 配置覆盖原配置（原 next.config.js 未提交改动）
COPY deploy/docker/next.config.js ./next.config.js

RUN npm run build

# ───────────────────────── Stage 3: runner ─────────────────────────
FROM node:${NODE_VERSION}-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# 非 root 运行：固定 uid/gid 1001，便于宿主目录权限对齐
RUN addgroup -g 1001 -S nodejs \
 && adduser -S -u 1001 -G nodejs nextjs

# standalone 产物自带精简 node_modules 与 server.js
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# 预建图片优化缓存目录并交出属主：
# 只读根文件系统下该目录由具名卷挂载覆盖，Docker 会继承这里的属主，
# 否则 tmpfs 默认 root:root，非 root 进程写不进去，图片优化直接 500
RUN mkdir -p /app/.next/cache && chown -R nextjs:nodejs /app/.next/cache

USER nextjs
EXPOSE 3000

# 用 node 内置 fetch 做探活，不额外装 curl（减小攻击面）
HEALTHCHECK --interval=30s --timeout=3s --start-period=25s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
