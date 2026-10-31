/**
 * 容器构建专用 Next 配置 —— 由 Dockerfile 覆盖到 /app/next.config.js
 * 与仓库原有的 next.config.js 唯一差异：开启 output: 'standalone'
 * 原文件保持不动，删除 deploy/ 目录即可完全回退。
 */
/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['lunar-javascript'],
  output: 'standalone',
};

module.exports = nextConfig;
