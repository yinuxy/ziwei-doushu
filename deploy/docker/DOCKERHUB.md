# 紫微斗数排盘引擎（容器版）

基于倪海厦《天纪》体系的紫微斗数排盘引擎，打包为开箱可运行的单容器镜像。

上游项目：[Renhuai123/ziwei-doushu](https://github.com/Renhuai123/ziwei-doushu)（MIT）

- 真太阳时校正、1986–1991 中国夏令时判定、闰月四种口径、晚子时换日
- 生年四化 / 大限流年四化 / 飞星自化，星曜亮度 7 档可切换流派
- 古籍库（紫微斗数全集 / 全书 / 骨髓赋）全文检索
- 14 主星 × 12 宫位命理百科，1100+ 行格局规则库
- **纯前端排盘，不依赖外部 API，不需要任何 API Key**

> 本镜像是上游「排盘引擎 + 数据集开放快照」的容器封装。AI 解读（`/api/interpret`）
> 与用户系统不在开源范围内，相关入口会提示接口缺失，属预期行为。

## 快速开始

```bash
docker run -d --name ziwei \
  -p 3000:3000 \
  --restart unless-stopped \
  IMAGE_NAME:latest
```

打开 http://localhost:3000

带安全加固的推荐启动方式（只读根文件系统 + 非 root + 资源限额）：

```bash
docker run -d --name ziwei \
  -p 127.0.0.1:3000:3000 \
  --restart unless-stopped \
  --read-only \
  --tmpfs /tmp:size=64m,mode=1777 \
  -v ziwei-cache:/app/.next/cache \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --memory 512m \
  IMAGE_NAME:latest
```

## 配置

| 变量 | 生效时机 | 说明 |
|---|---|---|
| `PORT` | 运行时 | 监听端口，默认 `3000` |
| `HOSTNAME` | 运行时 | 监听地址，默认 `0.0.0.0` |
| `NEXT_PUBLIC_SITE_URL` | **构建期** | 站点根地址，固化进 `sitemap.xml`、`robots.txt`、canonical、OG |

**重要**：`NEXT_PUBLIC_SITE_URL` 是构建期变量。`sitemap.xml` 与 `robots.txt` 属静态预渲染产物，
域名在 build 时就写死了，**容器启动后再改环境变量不会生效**。需要用自己域名时请自行构建：

```bash
docker build \
  --build-arg NEXT_PUBLIC_SITE_URL=https://你的域名 \
  -f deploy/docker/Dockerfile \
  -t 你的用户名/ziwei-doushu:latest .
```

## 特性

- 多阶段构建，运行时镜像不含源码与构建工具链
- 非 root 运行（uid/gid 1001）
- 内置 `HEALTHCHECK`，可直接接编排健康探针
- 支持 `linux/amd64` 与 `linux/arm64`
- 启动约 1 秒内可服务，常驻内存约 80–150MB

## 验证

```bash
# 健康状态
docker inspect --format '{{.State.Health.Status}}' ziwei

# 探活
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/chart
```

## 回滚

镜像按 git 提交 SHA 打标签，任一版本可精确回退：

```bash
docker run -d -p 3000:3000 IMAGE_NAME:sha-xxxxxxx
```

## 许可

代码 MIT；古籍数据集遵循上游 `DATASET-LICENSE`（二次发布需注明来源）。
