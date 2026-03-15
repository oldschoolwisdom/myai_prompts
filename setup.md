# osw-ai-template 建置教學

這份文件說明如何用 `osw-ai-template` 建立一個新的 AI 協作專案。

## 1. 概念先分清楚

兩支腳本分工如下：

1. `bootstrap-forgejo.sh`：建立遠端 repos、角色帳號、tokens、labels；若 `.env` 有設定 `*_TEMPLATE_REPO`，也會自動從 template repo clone 並 push 初始內容
2. `setup.sh`：建立本機工作目錄、clone/pull repos、複製 prompts/scripts、產生各角色 `.env`

也就是說，**`setup.sh` 不負責建立遠端 repo**。

## 2. 命名規則

範本預設採用：

```dotenv
PROJECT_NAME=osw-ai-template
PROJECT_SLUG=${PROJECT_NAME}
FORGEJO_ORG=${PROJECT_NAME}

AI_REPO=ai
SPEC_REPO=spec
APP_REPO=app
SERVER_REPO=server
DATA_REPO=data
QA_REPO=qa
DOCS_REPO=docs
I18N_REPO=i18n
UX_REPO=ux
OPS_REPO=ops
RELEASE_REPO=release
SERVICES_REPO=services

ROLE_ACCOUNT_PREFIX=${PROJECT_SLUG}
ROLE_ACCOUNT_SEPARATOR=-
```

因此：

- repo 預設名稱是 `spec`、`app`、`server`...  
- 角色帳號預設名稱是 `project-spec`、`project-app`、`project-server`...

## 3. 從範本建立新專案

```bash
git clone ssh://git@git.osw.tw:2222/osw-ai-template/osw-ai-template.git ai
cd ai
cp .env.example .env
```

然後編輯 `.env`，至少確認：

```dotenv
PROJECT_NAME=my-project
PROJECT_SLUG=my-project
FORGEJO_ORG=my-project
ADMIN_TOKEN=你的 Forgejo admin token
ROLE_TEAM_NAME=my-project-automation
ROLE_ACCOUNT_PREFIX=my-project
```

若你要改 repo 命名，也在這裡設定，例如：

```dotenv
AI_REPO=ai
SPEC_REPO=spec
APP_REPO=app
SERVER_REPO=server
```

## 4. 建立遠端資源

```bash
./bootstrap-forgejo.sh
```

這一步會：

- 建立缺少的 repos
- 建立 / 更新 automation team
- 建立各角色帳號
- 為各角色建立 token 並回寫 `.env`
- 建立標準 labels
- 若 `.env` 有設定 `*_TEMPLATE_REPO`，自動從 template repo clone 並 push 初始內容

預檢會檢查：

- `.env` 可寫
- 必要變數存在
- repo 名稱不重複
- `ADMIN_TOKEN` 可存取 admin API
- `FORGEJO_ORG` 可存取

## 5. （選填）設定初始內容來源

如果你希望新 repo 一開始就有初始內容，在執行 bootstrap 前，先在 `.env` 設定各角色的 template URL：

```dotenv
SPEC_TEMPLATE_REPO=ssh://git@git.osw.tw:2222/your-org/spec-template.git
APP_TEMPLATE_REPO=ssh://git@git.osw.tw:2222/your-org/app-template.git
# 其餘角色留空代表不 seed
```

規則：

1. 支援任何 git URL（SSH / HTTPS）
2. 遠端 repo 已有內容就跳過，不覆寫
3. 無法 clone template 時只警告，不中止整個 bootstrap

## 6. 初始化本機工作目錄

```bash
./setup.sh
```

這一步會在 `ai/` 上一層建立：

```text
spec/
app/
server/
data/
qa/
docs/
i18n/
ux/
ops/
release/
services/
```

並且：

- clone 或 pull 對應 repo
- 把 `prompts/` 與 `scripts/` 複製到各角色 `ai/`
- 產生每個角色的 `.env`
- 產生 dispatcher 用的 `../.env`

## 7. 啟動角色

```bash
./start.sh spec
./roles/app.sh
./roles/all.sh chat
```

## 8. 名稱解析 helper

由於 repo 名稱和角色帳號名稱已拆開，腳本或 prompt 中若要查實際名稱，可用：

```bash
bash ai/scripts/ltc-role-ref.sh spec repo
bash ai/scripts/ltc-role-ref.sh spec account
bash ai/scripts/ltc-role-ref.sh spec token-var
```

## 9. 建議完整流程

```bash
cp .env.example .env
# 編輯 .env（含選填的 *_TEMPLATE_REPO）

./bootstrap-forgejo.sh
./setup.sh
./roles/dispatcher.sh chat
./roles/spec.sh chat
```
