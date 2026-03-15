# 共用規範

所有角色（spec 角色、app 角色、server 角色、data 角色、qa 角色、ops 角色、dispatcher）共同遵守。

## 整體工作流

```
任何角色 發 [Request]
    │
    └── spec 角色 審核 → 更新規格文件
                │
                └── 依變更範圍，同時發 [Task] 給所有相關角色：
                    ├── data 角色    — 需要修改資料表/migration 時
                    ├── server 角色  — 需要修改 API/業務邏輯時
                    ├── ops 角色    — 需要部署/環境變更/infra 調整時
                    ├── qa 角色     — 需要驗收測試時
                    ├── app 角色    — 需要修改畫面/UI 時
                    ├── ux 角色     — 需要設計規範決策時
                    ├── docs 角色   — 需要更新使用者文件或 API 文件時
                    └── release 角色 — 里程碑完成，準備版本發布時
```

> **例外路徑**：`i18n` 角色 的任務由 **app 角色** 直接發起（不經過 spec），因為翻譯需求是 app 開發過程中動態產生的 UI 字串。

**核心原則：任何新功能需求都必須先有 spec，才能實作。**  
不論使用者跟哪個角色討論新功能，該角色都應先向 spec 角色 發 [Request]，等規格確立後再開始實作。

## 規格分層原則

- **維持一份產品規格主體** — 不把 app / server / web 拆成彼此獨立的 spec 主體，而是在同一份 `spec/` 內分層管理
- **`spec/shared/` 放跨端共用規則** — 名詞、流程、權限、狀態、產品行為等共用規格集中於 shared
- **資料層只定義共用資料契約** — canonical domain model、DDL、constraints、indexes、RLS 與跨層資料語意放在 `spec/data/`
- **server 層負責 API 與服務設計** — `spec/server/` 定義 API、服務邏輯、部署需求，但不重複定義 canonical 資料模型
- **app / web 層負責體驗與畫面** — `spec/app/`、`spec/web/` 只描述畫面流程、互動、顯示需求與對外行為，不規定 app / web 內部 class、state、cache、view model 怎麼建模
- **實作層擁有內部模型設計** — app / web / server 可以各自維護自己的 internal model、state model、view model、mapper，只要符合 shared/data/server 定義的外部契約

## 決策紀錄規則

- **每一個重要決定都要留下決策紀錄** — 不是只有架構大改才寫；只要牽涉資料契約、API 取捨、流程改變、權限規則、跨角色邊界、重要 UX/技術取捨，都要記錄
- **統一寫入 `spec/decisions/` 目錄** — 不再使用單一 `decisions.md`，也不把全域決策綁在 `server/`
- **檔名格式固定為 `YYMMDD_SERIAL_KEYWORD.md`** — 例如 `260308_001_DataModelBoundary.md`
- **建議保留 `spec/decisions/README.md` 當索引** — 用來整理決策清單與連結
- **決策紀錄要寫過程，不只寫結論** — 至少包含背景、候選方案、最後決定、取捨理由、影響範圍
- **遇到需要裁決的情況時先找 spec 角色** — 其他角色可以提出建議，但不要只在 issue/comment 中口頭決定而不落地到 `spec/decisions/`
- **決策規則本身也是決策** — 若你改了決策紀錄方式、檔名規則或索引方式，也要新增一筆決策檔留下原因

## 溝通語言規範

- **內部協作預設使用繁體中文** — Issue body、留言、triage 分流內容、決策紀錄、進度回報與角色之間的協作文字，一律使用繁體中文
- **Issue 前綴保留既定英文標記** — `[Request]`、`[Task]`、`[Bug]`、`[Triage]` 不翻譯；其後標題與內容使用繁體中文
- **識別字保持原文** — 指令、程式碼、API path、schema/table/column 名稱、label 名稱、repo/branch/file path、commit hash、環境變數與腳本名稱不要翻譯
- **對外內容依目標語系處理** — 使用者文件、翻譯檔與對客回覆若已有目標語系要求，依該角色規則處理；未特別指定時，內部協作仍以繁體中文為準

## Issue 標題慣例

| 前綴 | 方向 | 用途 |
|------|------|------|
| `[Request]` | 任何角色 → spec | 請求新增/修改規格 |
| `[Task]` | spec / dispatcher → 相關角色 | 依規格實作的任務，或依既有規格 / 已確認行為補齊文件 |
| `[Bug]` | 任何方向 | 缺陷修復 |
| `[Triage]` | services / 產品負責人 → dispatcher（ai repo） | 疑似異常分流與協調 |

**dispatcher 只負責 intake / 分流 / 跨角色協調，不是所有工作的總閘門。**  
已有明確 owner 的下游工作可直接依既定流程流轉，例如 `spec → app/server/data/docs/qa`、`app/server/data → qa`；只有來源不明、需要判定方向、或需要跨角色協調的事項才進 `[Triage]` / dispatcher。

### [Bug] 處理流程

```
任何角色（不含 services 角色）發現缺陷
    │
    ├── 確認行為與 spec 不符（不是操作問題）
    │
    └── 在對應 repo 建立 [Bug] Issue，assign 給負責角色
        ├── 畫面/UI 問題  → app 角色
        ├── API/邏輯問題  → server 角色
        └── 資料/schema 問題 → data 角色

負責角色 修復
    │
    ├── 修復並 commit & push
    └── assign 給 qa 角色 驗收

qa 角色 驗收
    ├── 只依 spec、Issue 驗收條件與可觀察結果驗證
    ├── 通過 → assign 給 Issue 的原始建立者（issue.user.login）
    └── 未通過 → 回覆不符項目，assign 回負責角色

原始建立者 確認後關閉 Issue
```

**注意**：[Bug] 不需要先經過 spec 審核，可直接由發現者發出。但若修復過程發現規格本身有問題，應另發 `[Request]` 給 spec 角色。  
`services` 角色 不負責判定是否為 Bug；收到客戶異常回報時，只負責依 `docs/user/` 回覆可確認的使用資訊，並告知已轉交團隊確認。

### [Triage] 處理流程

```
services 角色 或 產品負責人
在 dispatcher repo（即 ai repo）建立 [Triage] Issue
    │
    ├── 加上 `type: triage` + `status: pending-review`
    ├── assign 給 dispatcher 角色
    │
    ├── dispatcher 角色 審閱資訊是否足夠
    │   ├── 開始處理 → 改為 `status: in-progress`
    │   ├── 不足 → 改為 `status: pending-input`
    │   │        回覆需補充的重現步驟 / 環境 / 截圖，assign 回 services 角色 或發起人
    │   │
    │   ├── services 角色 / 發起人 補件完成
    │   │   → 改回 `status: pending-review`，assign 回 dispatcher 角色
    │   └── 足夠 → 判斷分流方向
    │       ├── 疑似缺陷
    │       │   （既有 spec / 文件 / 已確認行為明確，但實際結果不符）
    │       │   → 建立 [Bug] 給 app / server / data 角色
    │       ├── 疑似規格缺口
    │       │   （spec 本身未定義、互相衝突，或無法支持對外說明）
    │       │   → 建立 [Request] 給 spec 角色
    │       ├── 疑似文件缺口
    │       │   （spec 或已確認行為已明確，但 docs/user 未反映、過期或不足以回答）
    │       │   → 建立 [Task] 給 docs 角色
    │       └── 純新功能建議
    │           （客戶是在提出想要的新能力，不是在描述既有行為或文件矛盾）
    │           → 改為 `status: rejected`
    │             不當作 triage 缺陷；若產品負責人要評估，再另發 [Request] 給 spec 角色
    │
    ├── dispatcher 在 [Triage] Issue 留下分流結果與下游 Issue 連結
    │
    └── 下游 Issue 有更新時，dispatcher 更新 [Triage] Issue，並維持 `status: in-progress`
        ├── 若只需通知客戶目前進度 → @mention services 角色，不切換 triage 狀態
        ├── 問題已修復或已有最終結論 → 改為 `status: pending-confirmation`
        │   assign 回 triage 發起人；若需對客說明，先 @mention services 角色
        └── triage 發起人確認 / services 已通知客戶後關閉 [Triage] Issue
```

> `dispatcher repo` 使用 `bash ai/scripts/ltc-role-ref.sh dispatcher repo` 取得；目前對應 ai repo，不需將 repo 改名為 dispatcher。
> `docs gap` 的前提是：既有 spec 或已確認行為已經明確；若連這個前提都沒有，就不是 docs gap，而是 spec gap 或純功能建議。

### [Triage] 狀態規範

- 建立 triage 時：`type: triage` + `status: pending-review`
- dispatcher 開始處理時：改為 `status: in-progress`
- `status: in-progress` 代表 triage 已決定進入處理，且已有 dispatcher 或下游角色在接手；其他人看到可先略過，避免重複處理
- 需要 services 角色 / 發起人 補資訊時：改為 `status: pending-input`
- 補件後送回 dispatcher 時：改回 `status: pending-review`
- triage 已完成分流並持續追蹤下游 Issue 時：維持 `status: in-progress`
- 已有最終結論，等待發起人 / 客服收尾時：改為 `status: pending-confirmation`
- triage 判定不成立、重複、或純新功能建議時：改為 `status: rejected`

## Labels 狀態規則

各 repo 使用相同的 label 名稱標示 Issue 進度：

| Label | 含義 | 設定時機 |
|-------|------|----------|
| `status: pending-review` | 等待審核 / 分流 | 發起 [Request] 或 [Triage] 時 |
| `status: pending-input` | 等待補充資訊 | triage 需要 services 角色 / 發起人 補件時 |
| `status: in-progress` | 正在處理中 | 角色開始處理 Issue 時 |
| `status: pending-qa` | 等待 QA 驗收 | 實作完成，assign 給 qa 角色 時 |
| `status: pending-confirmation` | 等待發起人確認 | 驗收通過或規格已更新，assign 給發起人時 |
| `status: rejected` | 請求 / triage 被退回 | 請求不合理或 triage 判定不成立時 |

各 repo 的 label ID 不同，需動態查詢。使用 `ltc-label-id.sh` 取得 ID：

```bash
# 查詢 label ID
LABEL_ID=$(bash ai/scripts/ltc-label-id.sh {repo} "status: in-progress")
bash ai/scripts/ltc-label-add.sh {repo} {number} "$LABEL_ID"
```

## Issue 關閉與 Assign 規則

1. **只有發起人才能關閉 Issue** — 完成後 assign 給發起人，由對方確認後自行關閉
2. **完成工作時 @mention 下一個角色** — 確保通知鏈不中斷
3. **建立 Issue 時必須指定 assignee** — 明確指定負責處理的角色
4. **關閉 Issue 前必須 @mention 發起人** — 讓發起人知道結果

## Git 規則

- **啟動時不需要 pull** — `scripts/run-role.sh` 已在啟動前完成 `code/` 和 `spec/` 的 pull
- **收到新任務時 pull** — 處理 Issue 前執行 `git -C spec/ pull` 取得最新規格
- **完成修改後直接 commit & push** — 不需要詢問使用者
- **只改自己的 code/ 目錄** — 不要修改其他角色的檔案
- **路徑以工作目錄為基準** — 例如在 `app/` 下，spec 路徑為 `spec/`，不是 `../spec`

## 啟動規則

啟動時的**未讀通知**摘要已由 `scripts/run-role.sh` 預先掃描並注入：

- 直接根據啟動提示中的通知摘要處理
- 摘要為空 = 無未讀通知，但仍可能有 open issues — 用 `bash ai/scripts/ltc-list-issues.sh <repo>` 查詢
- **禁止自行呼叫通知 API** — 通知查詢由 `scripts/run-role.sh` 負責
- **處理完所有通知後**執行 `bash ai/scripts/ltc-mark-read.sh` 標記已讀

## Forgejo 操作規則

`FORGEJO_TOKEN` 已由 `scripts/run-role.sh` 預載到環境變數，腳本自動使用，**不需要手動查找 token**。

repo 名稱與角色帳號名稱可能被 `.env` 覆寫，**不要硬編碼**；需要時用：

- `bash ai/scripts/ltc-role-ref.sh <role> repo`
- `bash ai/scripts/ltc-role-ref.sh <role> account`

**禁止直接使用 `curl` 或 `gh`**，所有 Forgejo 操作只能透過 `ai/scripts/` 執行：

| 腳本 | 用途 |
|------|------|
| `ltc-list-issues.sh <repo>` | 列出 repo 的 open issues |
| `ltc-get-issue.sh <repo> <number>` | 取得 issue 詳情（含 body、發起人）|
| `ltc-get-comments.sh <repo> <number>` | 取得 issue 留言紀錄 |
| `ltc-comment.sh <repo> <number> <body>` | 發 Issue 留言 |
| `ltc-assign.sh <repo> <number> <assignee>` | 指派負責人 |
| `ltc-label-id.sh <repo> <label-name>` | 查詢 label 的數字 ID |
| `ltc-label-add.sh <repo> <number> <label_id>` | 加 label |
| `ltc-label-del.sh <repo> <number> <label_id>` | 移除 label |
| `ltc-close.sh <repo> <number>` | 關閉 Issue |
| `ltc-create-issue.sh <repo> <title> <body> <assignee>` | 建立 Issue |
| `ltc-mark-read.sh` | 標記所有通知已讀（處理完後執行）|

如需上述以外的 Forgejo 操作，向產品負責人說明需求，不要自行呼叫 `curl` 或 `gh`。
