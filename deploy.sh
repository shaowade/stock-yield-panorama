#!/bin/bash
set -e
: "${GH_TOKEN:?需要 GH_TOKEN}"
REPO="${REPO:-stock-yield-panorama}"
API="https://api.github.com"
H1="Authorization: Bearer $GH_TOKEN"
H2="Accept: application/vnd.github+json"

# 带重试的 API 调用：api.github.com 偶发超时
api() {  # api METHOD PATH [DATA]
  local m=$1 p=$2 d=$3 out=/tmp/api.out code
  for i in 1 2 3 4 5; do
    if [ -n "$d" ]; then
      code=$(curl -s -o $out -w '%{http_code}' --max-time 20 -X "$m" -H "$H1" -H "$H2" -d "$d" "$API$p" || true)
    else
      code=$(curl -s -o $out -w '%{http_code}' --max-time 20 -X "$m" -H "$H1" -H "$H2" "$API$p" || true)
    fi
    [ "$code" != "000" ] && break
    sleep 2
  done
  echo "$code"
}

LOGIN=$(python3 -c "import json;print(json.load(open('/tmp/u.json'))['login'])" 2>/dev/null || echo shaowade)
echo "账号: $LOGIN"

C=$(api GET "/repos/$LOGIN/$REPO")
echo "仓库检查: $C"
if [ "$C" = "404" ]; then
  C2=$(api POST "/user/repos" "{\"name\":\"$REPO\",\"description\":\"股息率全景表 · 股息网格 / 买卖计划 / ETF 梯度\",\"private\":false,\"has_issues\":false,\"has_wiki\":false,\"auto_init\":false}")
  echo "创建仓库: $C2"
  [ "$C2" = "201" ] || { cat /tmp/api.out; exit 1; }
fi

cd "$(dirname "$0")"
rm -rf .git
git init -q -b main
git add -A
git -c user.email="$LOGIN@users.noreply.github.com" -c user.name="$LOGIN" commit -qm "股息率全景表 v1 · 私密 Gist 云端同步"
git remote add origin "https://x-access-token:$GH_TOKEN@github.com/$LOGIN/$REPO.git"
git push -q -f origin main
git remote remove origin
echo "推送完成"

C3=$(api POST "/repos/$LOGIN/$REPO/pages" '{"source":{"branch":"main","path":"/"}}')
echo "开启 Pages: $C3"
cat /tmp/api.out | head -c 300; echo
