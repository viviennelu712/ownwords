# INSTALL_FOR_AI — 原話 OwnWords

供使用者的 Claude Code／Codex 在 **Apple 晶片 Mac 本機**執行的安裝說明。先閱讀本文件與腳本再操作。版本依 `app/Info.plist` 為 0.7.0；本文件以程式靜態核對撰寫，**尚未完成乾淨 Mac 的全流程實測**。標「待確認」之處不可宣稱已通過。

本機安裝不需要 Apple 開發者帳號、登入 OwnWords 或設定雲端 API 金鑰。安裝會建立臨時簽署的 App；不要替使用者發布、推送或建立 GitHub 儲存庫。

## 1. 確認機型、系統與工具

先執行唯讀檢查：

```sh
uname -m
sysctl -n hw.optional.arm64
sw_vers -productVersion
xcode-select -p
xcrun swift --version
git --version
```

- 需要 Apple silicon（M1 或之後），`hw.optional.arm64` 應為 `1`。終端機的 `uname -m` 應為 `arm64`；若在 Apple silicon 上顯示 `x86_64`，請改用原生終端機，勿沿用 Rosetta 建置。Intel 機型停止本流程。
- 需要 macOS 14.0 或以上；依據為 `Package.swift` 及 `app/Info.plist`。
- 套件宣告 `swift-tools-version: 5.9`；乾淨環境的最低可用工具鏈版本**待確認**，不要只憑宣告保證 Swift 5.9 可建置。開發測試另用到 `Testing`，見開發文件。
- 若缺 Command Line Tools，執行 `xcode-select --install`，告訴使用者完成系統安裝視窗後再繼續。腳本使用 Swift Package Manager、`codesign`、`ditto`、`open`，不要求付費開發者帳號。
- 告知使用者首次需連網取得程式、Swift 相依與 Hugging Face 模型。Whisper 選用 `openai_whisper-large-v3-v20240930_626MB`；名稱中的 626MB 不等於整個安裝大小。完整下載量、所需剩餘空間、最低 RAM 與首輪耗時**待確認**，先檢查 `df -h .`，不要保證固定數字。

## 2. 取得原始碼

若已在完整的原始碼目錄，不必再 clone。否則從官方儲存庫取得：https://github.com/viviennelu712/ownwords

```sh
git clone https://github.com/viviennelu712/ownwords.git OwnWords
cd OwnWords
```

確認有 `Package.swift`、`Package.resolved`、`Sources/`、`app/`、`proofreader/`、`scripts/build-app.sh` 與 `scripts/install-local.sh`。閱讀兩份腳本；避免覆蓋使用者既有的工作目錄。

## 3. 建置（只做建置時）

在專案根目錄執行：

```sh
zsh scripts/build-app.sh
```

腳本實際執行 `swift build -c release --product LocalVoiceInputMac`，重建 `dist/OwnWords.app`，複製圖示、校對程式與第三方授權，再執行 `codesign --force --deep --sign -`。它會刪除舊的 `dist/OwnWords.app`；這不是 Developer ID 簽署或公證。

**若下一步要正式安裝，直接執行第 4 步即可；安裝腳本本身會完成本步，不必連續建置兩次。**不要用 `swift run` 取代 App bundle 安裝，也不要手動改 bundle ID 或重簽已裝好的其他副本。

## 4. 安裝並啟動

先告訴使用者：此步會停止執行中的 `LocalVoiceInputMac`、取代 `~/Applications/原話.app`，並開啟新副本；既有個人詞庫、留底與偏好設定不會被腳本清除。若是重新安裝，要重新勾兩項權限。不要把舊機的個人資料打包給新使用者。

```sh
zsh scripts/install-local.sh
```

實際順序是：呼叫建置腳本 → `pkill -x LocalVoiceInputMac` → 建立 `~/Applications` → 刪除該處舊的 `原話.app` → 用 `ditto` 複製新 App → `open` 啟動。

請固定用這個安裝位置。不要指向舊 README 的 `dist/語音輸入.app`，也不要另複製到 `/Applications` 造成兩份混用。手動再開啟的指令是：

```sh
open "$HOME/Applications/原話.app"
```

## 5. 告訴使用者手動開啟三項權限

AI 必須清楚告知以下位置；不能只說「權限已開」，也不能把命令執行成功當成使用者已授權。系統設定中的勾選與系統密碼由使用者自己操作。

| 權限 | 到哪裡開 | 用途與時機 |
|---|---|---|
| 輔助使用 | 系統設定 → 隱私權與安全性 → 輔助使用 → 開啟「原話」／OwnWords | 模擬 ⌘V 貼字、鍵盤監聽所需檢查，以及取得游標位置 |
| 輸入監控 | 系統設定 → 隱私權與安全性 → 輸入監控 → 開啟「原話」／OwnWords | 偵測說話鍵、Esc 與修飾鍵組合；程式不儲存其他鍵盤輸入 |
| 麥克風 | 系統設定 → 隱私權與安全性 → 麥克風 → 開啟「原話」／OwnWords | 在第一次開始錄音時請求；系統彈窗請按允許 |

App 先檢查輔助使用，再請求輸入監控。開完第一項後，可點「原話 → 檢查鍵盤與貼上權限」繼續；若麥克風清單還沒出現 App，先從 App 選單「開始錄音」觸發系統詢問。

**每次重新安裝後，「輔助使用」與「輸入監控」都要先關再開。**臨時簽署會讓 macOS 可能將重建後的版本當成新 App，即使清單看起來已勾選也要重做。若仍無效，在提供「－／＋」的權限清單移除舊項，再加入 `~/Applications/原話.app`，並按系統提示退出重開。不要重設所有 App 的權限；麥克風若仍有效，通常不用重設。

部分程式內提示還會顯示舊名稱「語音輸入／語音」；以實際安裝的 `原話.app` 為準。

## 6. 第一次辨識與模型等待

1. 打開空白文字文件，點一下文字輸入位置。
2. **按住右邊 ⌥ Option**說一句中性測試句，例如「今天先測試語音輸入。」，放開。
3. 第一次可能在「轉文字中…」停幾分鐘：WhisperKit 會下載、預熱並載入模型。先等待，不要因為短暫沒字就反覆重裝。
4. 完成後應貼到游標；之後同一程序已載入模型，通常會快得多。實際時間因機型、網路與快取而異。

Whisper／tokenizer 的下載根目錄預設為 `~/Documents/huggingface/`，其中語音模型在 `models/argmaxinc/whisperkit-coreml/`。推論在本機，但目前程式設 `download: true`，SDK 載入時可能查詢遠端檔案清單；**完全斷網冷啟動待確認**。不能承諾下載一次後從此絕不連網。

預設用右 Option，是因為 Fn（🌐）在 Mac 預設切換輸入法；多輸入法使用者可能同時切換輸入法。使用者可在「說話鍵」改成右 Command 或 Fn；不要為了安裝擅自改使用者的系統輸入法設定。

## 7. 選用：本機 AI 校對層

**可以不裝，預設也不啟用。**未就緒、啟動失敗或逾時時，App 仍用原本的辨識＋固定整理規則。先驗收基本語音輸入，再由使用者選擇是否加入此層。

### 程式實際需要什麼

- Apple silicon、可用的 Python 環境、`mlx-lm`、`pypinyin` 及其相依。
- 預設 Python 路徑：`~/.local/share/uv/tools/mlx-lm/bin/python`（`ProofreaderService.swift`）。
- 預設模型：`mlx-community/Qwen3-4B-Instruct-2507-4bit`，約束為 4B 參數、4bit 的本機語言模型；**實際下載 GB、磁碟占用與峰值 RAM 待確認**，不得把參數名稱當下載大小。
- 模型由 `mlx_lm.load()` 取得；Python Hugging Face 快取通常在 `~/.cache/huggingface/`，實際位置會受 `HF_HOME`／`HF_HUB_CACHE` 等設定影響。需要首次下載，不需要 OwnWords 帳號或雲端 API key。
- 此儲存庫**沒有**校對層安裝腳本或 Python 鎖檔。下列是依 import、App 預設路徑與本機已裝套件 metadata 整理的候選步驟，**乾淨環境相容性待確認**。觀察到 `mlx-lm 0.32.2` 要求 Python ≥3.11，`pypinyin` 為 0.55.0；這不是已完成安裝驗收的保證。

### 候選安裝步驟

先檢查 `command -v uv` 與 `uv tool dir`。若已有 mlx-lm 工具環境，先檢查版本及相依，勿直接 `--force` 蓋掉。若沒有 uv、但使用者已有 Homebrew，可用 `brew install uv`；若兩者皆無，uv 的獨立引導安裝方式**待確認**，先保留基本語音輸入，不為了選用功能擅自安裝整套 Homebrew。

```sh
uv tool install --python 3.11 'mlx-lm==0.32.2' --with 'pypinyin==0.55.0'
test -x "$HOME/.local/share/uv/tools/mlx-lm/bin/python"
"$HOME/.local/share/uv/tools/mlx-lm/bin/python" -c 'import mlx_lm, pypinyin; print("imports OK")'
```

`uv tool dir` 若不是預設位置，不要建立假路徑；確認實際環境的 Python 後，App 支援以下偏好設定（把佔位文字換成真實絕對路徑，退出 App 後再寫入）：

```sh
defaults write io.github.viviennelu712.ownwords proofreadPython -string '<mlx-lm 環境的 Python 絕對路徑>'
```

App 預設使用 bundle 內的 `proofreader/`。若使用者以前在 `~/Library/Application Support/OwnWords/proofreader/` 放過覆寫版，該處 `proofread_server.py` 會優先於 bundle；先確認是否仍需要，不要自動覆蓋或刪除。

可先從專案根目錄做一次獨立載入檢查（**會下載／載入大模型，可能等待數分鐘**）：

```sh
"$HOME/.local/share/uv/tools/mlx-lm/bin/python" proofreader/proofread_server.py
```

看到 `{"ready": true}` 後，可輸入一行 `{"id":1,"text":"今天先測試語音輸入。"}` 再按 Enter，應收到相同 id 的 JSON 回覆；用 Ctrl-C 結束這個獨立測試程序。若使用自訂 Python 路徑，改用同一路徑測試。不要同時讓 App 再載入另一份模型。

再開啟 `~/Applications/原話.app`，勾選「本機 AI 校對」，等待「本機 AI 校對：開著」。它用標準輸入／輸出和 App 溝通，**不是 HTTP server，不需要開連接埠**。不要只靠 `import` 成功宣稱模型已可運作。`OWNWORDS_PROOFREAD_MODEL` 可供子程序選模型；一般使用不需改，且從 Finder 啟動的 App 不一定繼承終端機環境變數。

## 8. 驗收與交付

向使用者逐項回報實際結果；未做的項目標「未驗證」，不要代填成功。

- `~/Applications/原話.app` 存在、可開啟，選單列有「原話」。
- 三項權限由使用者確認，按住右 Option 可錄音、放開後文字貼入測試文件；再測按一下開始／再按一下結束，以及 Esc 取消。
- 第一次轉錄完成後，再測一次，確認能持續輸入；記錄模型準備是否完成。
- 「最近說過的話」會保存最近 20 筆不重複文字，預設無停用開關。測完可用其「清除紀錄」刪除測試文字。
- 全新設定下「原話留底」與「本機 AI 校對」均未勾選；既有使用者設定會沿用，不要擅自關掉。詞庫初始只有註解範例，個人內容由使用者自己填。
- 若裝選用校對層，確認顯示「開著」、測過實際校對及關閉後基本輸入仍可用；否則回報「未安裝／未啟用」。
- 回報安裝路徑、版本 0.7.0、權限狀態與未完成事項，不收集或傳送使用者的錄音、偏好檔、個人詞庫或留底。

## 9. 常見問題

| 狀況 | 處理方式 |
|---|---|
| 右 Option 沒反應 | 確認選單的說話鍵；檢查輔助使用與輸入監控，重裝後兩項都先關再開；從選單「開始錄音」分辨鍵盤問題與麥克風問題 |
| 只有「已複製」／文字沒貼出 | 確認焦點在可編輯欄位及輔助使用權限，嘗試 ⌘V；也可從「最近說過的話」重貼 |
| 第一次「轉文字中…」很久 | 等待模型下載與準備；確認網路及磁碟。此版沒有完整下載進度介面。若持續失敗，回報錯誤文字，勿反覆重裝 |
| 權限列表有兩份或顯示舊名字 | 使用固定的 `~/Applications/原話.app`，移除清單中的舊項並重新加入；勿啟動 dist 的副本混用 |
| Fn 會切換輸入法 | 用預設右 Option，或在 App 選單改右 Command；不必動系統輸入法設定 |
| 系統阻擋開啟 | 確認是在本機由這份原始碼建置；到「系統設定 → 隱私權與安全性」查看具體提示，僅依系統提供的允許開啟操作。各系統版本提示待確認；不要關閉 Gatekeeper／SIP 或執行廣泛移除隔離屬性的指令 |
| 找不到本機 AI（mlx-lm） | 查 `proofreadPython` 指向的可執行檔及相依；先停用校對，基本語音輸入可繼續 |
| 校對一直準備中／停止了 | 用上方獨立程序查看錯誤；App 會捨棄子程序 stderr，選單看不到完整原因。確認模型、Python API 與記憶體，勿把私人句子貼到外部服務除錯 |
| 斷網後重新開 App 失敗 | 本機推論不等於 SDK 冷啟動完全不連網；目前待確認，先如實回報，勿擅改模型路徑或程式 |
| 重裝後還有舊紀錄／留底 | 這些存在 App bundle 外；用選單清最近紀錄、手動刪除不需要的留底檔。關閉留底不會刪除已存檔案 |

English: Apple silicon, macOS 14+, source build only. Run `zsh scripts/install-local.sh` from the project root (it builds, ad-hoc signs, installs to `~/Applications/原話.app`, and opens it). The user must grant Microphone, Accessibility, and Input Monitoring; after every reinstall toggle the latter two off and on. Use Right Option, wait for the first model preparation, and verify a real paste. Optional MLX proofreading is off by default and its clean-machine setup is still unverified. Never invent the public repository URL or mark unchecked steps as complete.
