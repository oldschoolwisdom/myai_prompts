# osw-ai-template

可複用的 AI 專案範本，包含角色 prompts、啟動腳本、Forgejo helper scripts 與協作規範。

## 內容

```text
osw-ai-template/
├── prompts/              ← 各角色 AI 的 system prompt（唯一來源）
├── scripts/              ← Forgejo 操作腳本與共用 helper
├── roles/                ← 分角色啟動腳本
├── bootstrap-forgejo.sh  ← 建立遠端 repos / 角色帳號 / tokens / labels，並可從 template repo seed 初始內容
├── setup.sh              ← 初始化本機工作目錄
├── start.sh              ← 通用啟動入口（例如 `./start.sh app`）
├── .env.example          ← 環境變數範本
└── setup.md              ← 完整建置教學
```

> 人工啟動請統一使用 `start.sh` 或 `roles/*.sh`；`scripts/run-role.sh` 是內部實作。

## 命名模型

- 範本本身：`osw-ai-template`
- repo 預設命名：`ai`、`spec`、`app`、`server`、`data`、`qa`、`docs`...
- 角色帳號預設命名：`${ROLE_ACCOUNT_PREFIX}-${role}`，例如 `myproj-spec`
- 以上都可由 `.env` 覆寫

也就是說，**repo 名稱**與**角色帳號名稱**已經拆開：

- repo 不再強迫使用 `LTC-*`
- 角色帳號也不再等於 repo 名稱

## 快速開始

```bash
# 1. Clone 範本 repo
git clone ssh://git@git.osw.tw:2222/osw-ai-template/osw-ai-template.git ai
cd ai

# 2. 設定專案名稱、Forgejo org、repo 名稱與 token
cp .env.example .env

# 3. （選填）在 .env 設定各角色的 template repo URL
#    SPEC_TEMPLATE_REPO=ssh://git@...
#    APP_TEMPLATE_REPO=ssh://git@...

# 4. 建立遠端 repos / 角色帳號 / tokens / labels，並 seed 初始內容
./bootstrap-forgejo.sh

# 5. 初始化本機工作目錄
./setup.sh

# 6. 啟動角色 AI
./start.sh app
```

## `.env` 核心設定

常用欄位：

- `PROJECT_NAME` / `PROJECT_SLUG`
- `FORGEJO_BASE_URL` / `FORGEJO_API_BASE` / `FORGEJO_SSH_BASE`
- `FORGEJO_ORG`
- `ROLE_TEAM_NAME`
- `ROLE_ACCOUNT_PREFIX` / `ROLE_ACCOUNT_SEPARATOR`
- `AI_REPO`, `SPEC_REPO`, `APP_REPO`, `SERVER_REPO`, `DATA_REPO`, `QA_REPO`
- `DOCS_REPO`, `I18N_REPO`, `UX_REPO`, `OPS_REPO`, `RELEASE_REPO`, `SERVICES_REPO`
- `ADMIN_TOKEN`, `SPEC_TOKEN`, `APP_TOKEN`, `SERVER_TOKEN` ... 等角色 token

舊的 `LTC_*` / `LR_*` / `LS_*` token 變數目前仍相容，但新的 canonical 命名已改成不帶專案前綴。

## 建議流程

建立新專案時，順序應是：

1. 複製範本 repo
2. 修改 `.env`
3. （選填）設定 `*_TEMPLATE_REPO` 欄位
4. 執行 `./bootstrap-forgejo.sh`
5. 執行 `./setup.sh`

其中：

- `bootstrap-forgejo.sh` 負責**遠端資源**（建 repo、角色、labels）；若有設定 `*_TEMPLATE_REPO`，也會自動 seed 初始內容
- `setup.sh` 負責**本機工作目錄**

## 資安注意

- `.env` 含 token，不會進版控
- prompts 與腳本只描述變數名稱，不保存實際密鑰
