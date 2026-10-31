#!/usr/bin/env bash
# 部署后冒烟验证 —— 全部路由 200 才算通过
# 用法：
#   ./verify.sh                        # 默认 http://127.0.0.1:3000
#   ./verify.sh https://zw.example.com # 指定域名
#   EXPECT_DOMAIN=zw.example.com ./verify.sh   # 额外校验 sitemap 域名是否正确
set -uo pipefail

BASE="${1:-http://127.0.0.1:3000}"
BASE="${BASE%/}"

PATHS=(
  /
  /chart
  /heming
  /library
  /knowledge
  /privacy
  /terms
  "/library/search?q=%E7%B4%AB%E5%BE%AE"
  /sitemap.xml
  /robots.txt
)

echo "冒烟目标: $BASE"
echo "----------------------------------------"

fail=0
for p in "${PATHS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$BASE$p" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    printf '  OK    %-3s  %s\n' "$code" "$p"
  else
    printf '  FAIL  %-3s  %s\n' "$code" "$p"
    fail=1
  fi
done

# 关键校验：sitemap 里的域名来自构建期 NEXT_PUBLIC_SITE_URL，
# 若与预期不符说明构建参数没传对，SEO 会把流量导到错误的域名
if [ -n "${EXPECT_DOMAIN:-}" ]; then
  echo "----------------------------------------"
  if curl -s --max-time 5 "$BASE/sitemap.xml" 2>/dev/null | grep -q "$EXPECT_DOMAIN"; then
    printf '  OK    sitemap 域名 = %s\n' "$EXPECT_DOMAIN"
  else
    printf '  FAIL  sitemap 未包含 %s（构建期变量未生效，需 --build 重建）\n' "$EXPECT_DOMAIN"
    fail=1
  fi
fi

echo "----------------------------------------"
if [ "$fail" -eq 0 ]; then
  echo "结果: 通过"
else
  echo "结果: 存在失败项"
fi
exit "$fail"
