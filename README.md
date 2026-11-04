# 原話 OwnWords

An AI voice dictation tool that keeps your words yours. 一款保留個人表達方式的 AI 語音輸入工具。

**Recognize, don't rewrite. 智慧辨識，不等於智慧改寫。**

macOS 本機語音輸入 App · 0.7.0 · Apple 晶片 Mac · Swift + WhisperKit

## Why OwnWords

以下是 Vivian 的逐字原話節錄；引號內保留原本的用字與標點。

2026-10-12〈原話 OwnWords——智慧辨識不等於智慧改寫〉：

> 「保留一個區別：AI語音工具 智慧辨識，不等於智慧改寫。」

> 「說話中途改口，工具能夠理解、修正錯字、補上標點；但不需要替你重新組織思想、改變語氣，甚至把你的情緒和個人表達習慣刪掉。」

2026-10-21〈GitHub——取之於此，還之於此〉：

> 「我感覺像AI幫我拿了很多東西了。所以我覺得我也要在上面放一些東西，就當是，就是我取自這裡我還之這裡是很合理的。」

## 它會做什麼

以下是目前程式行為的說明，與上方作者原話分開。

- 主動按鍵才錄音，用 WhisperKit 在 Mac 上辨識，貼到目前游標位置。目前辨識語言固定為中文，並處理常見英文工具名。
- 補中文標點、轉繁體及部分臺灣字形、套用你自己的「聽錯 → 正確」詞庫。
- 以固定規則清理部分嗯／呃、重複片段、起句重說及模型常加的片尾話。因此輸出並非逐字不動；規則也可能誤判，重要內容請自行確認。
- 可選用本機小 AI 校對；不安裝也能語音輸入。

### 本機 AI 可以幫你順，但不能替你寫

小 AI 分兩步工作，每一步都要通過程式檢查才算數。

**第一步：找聽錯的詞。**模型只能回傳「哪個詞聽錯 → 改成什麼」的 JSON 清單。程式逐條檢查：

1. 中文必須同音或近音，按拼音與指定的易混音規則比對。
2. 英文必須在內建清單或你的詞庫裡，且拼法或發音相似；已知英文詞不能隨意換成另一個已知詞。
3. 明確改口必須含「不對」「我是說」等線索，且只能保留原本說過的較短片段。

**第二步：順稿（30 字以上）。**模型可以刪結巴、放棄的半句和重講的前一次，修標點，並在換話題處分段。程式逐字比對：每個留下來的字都必須是原本講過的，而且順序不變；只要多出任何一個字，或刪得太多、一次刪太長，這次順稿就整段作廢。這條防的是「加字和換字」，它仍可能刪掉你想留的字，重要內容請自行確認。

通過後，Swift 再檢查整段的長度與相似度；校對未就緒、逾時或被拒絕，就使用固定規則整理後的辨識結果。這是限制 AI 修改範圍的防線，不是零錯誤保證。

## 它不會做什麼

不替你換字、加字、調換順序、換語氣、摘要或翻譯；不使用雲端語音／校對 API。不提供帳號、分析追蹤或 App 內建的雲端同步。目前沒有 iPhone／iPad App 或跨裝置同步功能。

## 隱私：語音與文字都在本機處理

OwnWords 本身不會上傳你的錄音、辨識文字、詞庫或留底內容，也沒有登入與遙測。**取得原始碼、建置相依套件與下載模型需要連網**；WhisperKit 啟動模型時仍可能查詢 Hugging Face。這些下載／查詢與把語音送去雲端辨識不同；完全斷網的冷啟動行為仍待確認。

以下「預設」指沒有既有偏好設定的新使用者；重裝不會自動清除設定或個人資料。

| 資料／功能 | 存放位置與預設行為 | 清除方式 |
|---|---|---|
| 暫存錄音 | 系統暫存目錄的 `local-voice-<UUID>.wav`；16 kHz、單聲道 WAV。辨識成功／失敗或取消後刪除；異常退出可能留到下次啟動清理 | 正常流程自動清理；不製作永久錄音庫 |
| 最近說過的話 | **預設會保存**最近 20 筆不重複的輸出文字，跨啟動保留；存在 App 的 `UserDefaults`，通常由 macOS 存於 `~/Library/Preferences/io.github.viviennelu712.ownwords.plist`。沒有獨立停用開關 | 「原話 → 最近說過的話 → 清除紀錄」 |
| 我的詞庫 | `~/Library/Application Support/OwnWords/我的詞庫.txt`；首次需要時建立，只有註解範例，沒有有效的個人規則；存檔後下一句套用 | 「編輯我的詞庫…」刪除規則並存檔 |
| 原話留底 | **預設關閉**。開啟後將輸出文字按時間寫入 `~/Documents/原話留底/YYYY-MM-DD.md`；AI 校對有改動時也記錄校對前文字。若已有自訂 `archiveFolder` 設定則使用該位置；不是原始音訊或完整未整理逐字稿 | 取消勾選只停止新增；既有檔案須自行刪除，程式沒有自動到期清除 |
| 本機 AI 校對 | **預設關閉**；開啟後透過本機 Python 子程序的標準輸入／輸出傳文字，在本機推論，不架設網路服務 | 選單關閉即可停止子程序；模型快取不會因此刪除 |
| 設定 | 說話鍵、上述開關、自訂路徑等存在同一 App 的 `UserDefaults` | 重裝仍會沿用；不要把自己的偏好檔打包分享 |
| 模型與下載快取 | Whisper／tokenizer 的預設下載根目錄為 `~/Documents/huggingface/`（含 `models/argmaxinc/whisperkit-coreml/`）；選用校對模型使用 Hugging Face Python 快取，通常在 `~/.cache/huggingface/`，可受環境變數影響 | 退出 App 後按需刪除對應模型快取；下次使用可能重新下載 |
| 剪貼簿 | 一般輸入先暫存原剪貼簿，用 ⌘V 貼上，約 0.6 秒後還原（期間若有新複製則不覆蓋）；貼上失敗或從最近紀錄重貼時，文字會留在剪貼簿 | 用新的複製內容取代 |

系統的文件同步、備份、通用剪貼簿與其他 App 的剪貼簿工具由使用者管理；OwnWords 不控制它們。若要避免系統同步留底檔案，請選擇不參與同步的位置。不要把個人詞庫、偏好檔、錄音或留底檔案加入公開儲存庫。

## 使用條件與安裝

- Apple 晶片（M1 或之後）的 Mac；不支援本安裝流程在 Intel Mac 上執行。
- macOS 14.0 或以上（`Package.swift` 與 `app/Info.plist` 的最低宣告）。
- Xcode Command Line Tools／可用的 Swift 工具鏈。套件宣告 Swift tools 5.9；乾淨環境最低可用工具鏈版本待確認。
- 首次建置與下載模型需要網路及可用磁碟空間；完整下載量、尖峰記憶體與最低建議 RAM 待確認。
- 麥克風、輔助使用、輸入監控權限。

目前沒有 Apple 開發者帳號，不提供預先建好的簽署／公證 App，採用**從原始碼建置**。

**把這個網址丟給你的 Claude Code 或 Codex，說：幫我裝**

網址：https://github.com/viviennelu712/ownwords完整步驟請看 [INSTALL_FOR_AI.md](INSTALL_FOR_AI.md)。AI 可以處理建置安裝，macOS 的權限勾選仍需要你操作。

## 預設說話鍵與操作

1. 點選要輸入文字的位置。
2. 按住**右邊 ⌥ Option**說話，放開就轉文字並貼上；或按一下開始、再按一下結束。
3. 錄音中按 **Esc** 可取消；單次錄音最多約 5 分鐘。

選單「原話 → 說話鍵」可改為右邊 ⌘ Command 或 Fn（🌐）。預設用右 Option，是因為 Fn（🌐）在 Mac 預設用來切換輸入法；裝多種輸入法時可能一邊錄音、一邊切換輸入法。

第一次辨識可能在「轉文字中…」停留幾分鐘：系統正在下載／準備模型，之後通常較快。**每次重新安裝後，輔助使用與輸入監控都要先關再開**；目前使用臨時簽署，macOS 可能將重建版本視為新的 App。

## 授權與開發

程式碼採 [MIT License](LICENSE)。**「OwnWords」「原話」名稱與 OwnWords 圖示保留，不授權衍生作品沿用；公開修改版請改用自己的名稱與圖示。**第三方框架與模型各有其授權，詳見 [來源與授權盤點](docs/SOURCE_AND_LICENSE_AUDIT.md) 及 [Third-Party Notices](app/ThirdPartyNotices.txt)；盤點中的第一版敘述需配合現況閱讀。

開發架構、建置／測試指令與舊版 README 留存於 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

## English

**Recognize, don't rewrite.** OwnWords is a local macOS dictation app for Apple silicon Macs running macOS 14 or later. It transcribes Chinese with WhisperKit, handles common English tool names, applies deterministic cleanup, and pastes at your cursor. It does not add words, swap in synonyms, reorder your thoughts, or summarize. Cleanup can still remove some hesitations, repeats, restarts, and trailing phrases, so review important text.

Optional local AI proofreading has two checked steps. First it returns individual correction proposals; Python checks Chinese sound similarity, English glossary membership and spelling/sound similarity, or explicit self-correction. Then, for 30+ characters, it may remove stumbles, fix punctuation and add paragraph breaks; every remaining character must have been said, in the same order, or the tidy is discarded. Swift adds a whole-text guard. Unavailable, rejected, or timed-out proofreading falls back to the cleaned transcript. The AI layer is off by default and is not required for dictation.

Audio, transcripts, vocabulary, and archives are not uploaded by OwnWords. Source, dependency, and model downloads require internet access, and model startup may query Hugging Face. Fully offline cold startup remains unverified. Temporary WAV files are deleted after processing or cancellation; crash leftovers are cleaned on the next launch. The last 20 distinct outputs are saved locally in app preferences by default, with a menu action to clear them. Daily text archiving is off by default; if enabled, files remain until you delete them. The vocabulary lives in `~/Library/Application Support/OwnWords/我的詞庫.txt`; archives default to `~/Documents/原話留底/`. Clipboard contents and OS-managed sync or backups are subject to your system settings. See the Chinese data table above for storage and deletion details.

Build from source using [INSTALL_FOR_AI.md](INSTALL_FOR_AI.md): give your Claude Code or Codex this repository URL and say “Help me install it.” The final public repository URL is pending. Grant Microphone, Accessibility, and Input Monitoring permissions yourself. After every reinstall, toggle Accessibility and Input Monitoring off and on again. First transcription may take several minutes to prepare the model.

Hold **Right Option** to talk and release to paste, or tap once to start and again to finish. Press Esc to cancel recording. Right Command and Fn are menu options; Right Option avoids Fn/Globe's input-source switching conflict.

Source code is MIT licensed. The OwnWords / 原話 names and icon are reserved; published derivatives must use their own branding. See [LICENSE](LICENSE) and [DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

程式碼採 [MIT 授權](LICENSE)；「OwnWords／原話」名稱與圖示另見 [NAME_AND_ICON.md](NAME_AND_ICON.md)。
