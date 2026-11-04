# OwnWords 開發說明

本文件保存開發資訊與原 README。一般使用與隱私見 [README](../README.md)，安裝代理請先讀 [INSTALL_FOR_AI](../INSTALL_FOR_AI.md)。

## 目前架構與版本

- `app/Info.plist`：0.7.0（build 10），最低 macOS 14.0，bundle ID `io.github.viviennelu712.ownwords`。
- `Sources/LocalVoiceInputMac/`：AppKit 選單、說話鍵、AVFoundation 暫存錄音、WhisperKit、本機 Python 子程序、權限、貼上與個人檔案管理。
- `Sources/VoiceInputCore/`：不依賴 App UI 的字詞修正、繁體／臺灣字形、標點、片段合併、重說／片尾過濾、個人詞庫與 AI 輸出防線。
- `Sources/VoiceInputBenchmark/`：以音訊檔測模型載入／辨識時間，會印出詞級時間、RAW、CLEAN；可能包含私人文字，不要提交真實輸出。
- `proofreader/`：選用 MLX 模型，透過 JSON lines 標準輸入／輸出工作；模型只列建議，Python 逐項驗證，Swift 再做整段守門。
- `Tests/VoiceInputCoreTests/`：核心規則測試；測資目前含真實使用片段，公開前需另外匿名化審查。
- `Package.swift` 固定 WhisperKit 0.9.4，`Package.resolved` 記錄 swift-transformers 0.1.8、swift-argument-parser 1.3.0。

## 建置、測試與安裝

在根目錄執行；以下是開發指令，不代表本次文件整理已執行過。

```sh
swift test
zsh scripts/build-app.sh
open 'dist/OwnWords.app'
```

`swift test` 使用 `import Testing`，需要帶有 Swift Testing 的工具鏈（例如 Swift 6）；乾淨環境的最低可用版本待確認。建置腳本的真正 product 是 `LocalVoiceInputMac`；手動組出 bundle、放入授權及校對資源，再以 `codesign --sign -` 臨時簽署。腳本沒有下載／安裝 Python 或 MLX。

日常固定安裝副本：

```sh
zsh scripts/install-local.sh
```

此腳本會再建置、停止 `LocalVoiceInputMac`、取代 `~/Applications/原話.app` 並啟動。**重新建置後安裝仍可能讓輔助使用與輸入監控失效，每次重裝都要先關再開。**固定路徑不能取代重新授權。對正在使用的版本，不要只為更新文件執行安裝或重簽。

預設說話鍵是右 Option，選單可改右 Command／Fn；另有 Control+Option+Space 的全域切換快捷鍵（`GlobalHotKey.swift`）。舊文件裡的 Fn 預設與 `語音輸入.app` 路徑已過時。

校對設定、資料位置及清除方式以現行 README 的隱私表為準。特別注意 `UserDefaults` 的 `archiveEnabled`、`proofreadEnabled` 在沒有既有值時都是 false，`recentTranscripts` 則會自動保留最多 20 筆。不要複製自己的 preferences、Application Support 詞庫或 Documents 留底進儲存庫。

## 本機 AI 校對的界線

`proofreader/system-prompt.txt` 要求只回 JSON 替換清單；`proofread_core.py` 限制原詞確實出現、中文同音／指定近音、英文清單與拼法／發音相似、明確改口的縮短片段，並阻擋反轉使用者詞庫。`ProofreadGuard.swift` 再做長度與相似度檢查。校對失敗或逾時使用原辨識經固定規則整理後的文字。

順稿步驟（`proofreader/tidy-prompt.txt`，30 字以上才跑）讓模型輸出整段，但 `check_tidy` 要求去掉標點後的輸出是原文的子序列（不能加字、換字、調序），且至少留 80%、單次不刪超過 40 字。

這不等於逐字保留：`TranscriptCleaner`、`TranscriptContextualCorrector`、`RestartRemover`、`HallucinationFilter` 仍會執行規則式刪除與修正；用公開、合成測資驗證誤刪邊界。第一步（找聽錯的詞）提示詞禁止 AI 動標點；標點只在順稿步驟改。

## 來源與公開前未完成項

[來源與授權盤點](SOURCE_AND_LICENSE_AUDIT.md) 保留第一版背景，並非最新行為保證：其中「尚未對外授權」已過時，第一版資料流也未涵蓋最近 20 筆、選用留底與本機 AI 校對；目前以根目錄 LICENSE 及程式為準。`app/ThirdPartyNotices.txt` 與建置腳本目前涵蓋 Swift 依賴及 Whisper；選用 MLX／Qwen 校對層的套件、模型 revision、授權與所需 notices 仍待確認。模型與 Python 相依尚未完整鎖定；乾淨環境安裝、模型下載量／記憶體及斷網冷啟動也待確認。

公開前另需處理已追蹤的內部成品與真實測資。隱私檢查報告交付於本次工作回覆，避免把詳細私人摘錄再寫進公開文件。

## 歷史 README：完整原文留存

以下逐字保留搬移前 README，供開發脈絡查閱。**這是歷史記錄，不是現行安裝指南或功能保證**：Fn 預設、舊 App 名稱、隱私行為及「之後可離線使用」等請以上方現況、現行 README 與 INSTALL_FOR_AI 為準；iPhone／iPad 與 iCloud 仍只是構想，未實作。內容完整保留，相對連結已依搬移後位置修正。

<details>
<summary>展開原 README（完整內容）</summary>

# 本機語音輸入

一個本機優先的 Apple 平台語音輸入工具。目前第一個可執行版本以 macOS 為目標；文字整理核心獨立成 `VoiceInputCore`，未來可供 iPhone／iPad App 共用。

## 第一版操作

1. 執行 App。
2. 允許麥克風及輔助使用權限。
3. 在任何文字輸入框按住 `Fn` 說話。
4. 說完放開 `Fn`，完成本機辨識並貼到游標位置。

第一次辨識會從 Hugging Face 下載 Whisper Core ML 模型，之後可離線使用。錄音只放在暫存資料夾，辨識完成或失敗後刪除。

中文標點採用兩層處理：先保留辨識模型判斷的逗號、問號等標點，再根據詞級時間的明顯停頓補齊斷句；每次放開 `Fn` 送出的中文至少會有結尾標點。

## 0.3 智慧校正

- 統一常見 AI 產品名稱，例如把 `Norbo LM`、`NOBOOK LM` 校正成 `NotebookLM`。
- 只在工具比較的上下文明確時把 `Cloud` 校正成 `Claude`；`Cloud Storage` 等真正的雲端用法會保留。
- 修復停頓造成的假斷句與接續詞重複，例如 `到。到檢查作業` 會變成 `到檢查作業`。
- 長停頓若落在「因為、所以、然後」等接續詞後，優先使用逗號而不是句號。
- 這一版只做高信心校正，不改寫或重新組織使用者原意。

## 開發

```sh
swift test
zsh scripts/build-app.sh
open 'dist/語音輸入.app'
```

日常測試請安裝固定副本，避免開發版重新簽署後使 Accessibility 權限失效：

```sh
zsh scripts/install-local.sh
```

目前電腦只有 Xcode Command Line Tools；Swift Package 可以建置，但正式簽署、App Store 打包及完整 Apple 平台開發仍需要安裝完整 Xcode。

## 兩台 Mac

`dist/語音輸入.app` 可以複製到另一台相近規格的 Apple Silicon Mac 測試。由於目前使用臨時簽署，另一台 Mac 可能要在「隱私權與安全性」中手動允許開啟；每台電腦也會各自下載一次模型、各自授權麥克風與輔助使用權限。

## 未來 iPhone／iPad

- 共用：文字整理規則、模型選擇策略、字典格式與測試資料。
- 平台專用：macOS 使用全域快捷鍵與 Accessibility；iPhone／iPad 需要鍵盤擴充套件或主 App 分享／複製流程。
- 跨裝置：個人字典與設定預計採可選的 iCloud／CloudKit，同步前會另做隱私盤點。

來源與授權請見 [`docs/SOURCE_AND_LICENSE_AUDIT.md`](SOURCE_AND_LICENSE_AUDIT.md)。

</details>
