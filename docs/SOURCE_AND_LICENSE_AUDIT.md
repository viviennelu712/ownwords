# 來源與授權盤點

更新日期：2026-07-12

> 本文件是工程來源盤點，不是法律意見。公開發布、收費或送交 App Store 前，應重新檢查依賴版本、素材與當時適用的條款。

## 結論

第一版採「乾淨的新專案 + WhisperKit」方案，不直接複製 Pindrop 的程式、名稱、圖示、翻譯、畫面或更新服務。

- 可以安全開發自用版。
- 選定的程式碼與 Whisper 模型權重允許修改與商業使用。
- 發布二進位檔時必須附上第三方授權聲明。
- 第一版不加入 telemetry、analytics、登入、雲端同步或雲端語音 API。
- 首次取得模型時會連線 Hugging Face；錄音與辨識本身在裝置上進行。

## 來源清單

| 類別 | 來源與固定版本 | 授權 | 自用 | 公開／商用 | 必須處理 |
|---|---|---|---|---|---|
| App 原始碼 | 本專案自行撰寫 | 尚未對外授權 | 是 | 發布前決定 | 不使用 Typeless/Pindrop 名稱與素材 |
| 語音框架 | [Argmax WhisperKit v0.9.4](https://github.com/argmaxinc/argmax-oss-swift/tree/v0.9.4) | MIT | 是 | 是 | 附 MIT copyright 與 license |
| Tokenizer／模型工具 | [Hugging Face swift-transformers 0.1.8](https://github.com/huggingface/swift-transformers/tree/0.1.8) | Apache-2.0 | 是 | 是 | 附 Apache-2.0；若有 NOTICE 則保留；標示修改 |
| Swift CLI 相依 | [Apple swift-argument-parser 1.3.0](https://github.com/apple/swift-argument-parser/tree/1.3.0) | Apache-2.0 | 是 | 是 | 它是 WhisperKit 套件宣告的相依；App target 不直接使用 |
| 語音模型與原始模型程式 | [OpenAI Whisper](https://github.com/openai/whisper) | MIT | 是 | 是 | 附 MIT copyright 與 license |
| Core ML 轉換權重 | [argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml) | 由 Whisper 模型轉換；上游 Whisper 程式與權重為 MIT | 是 | 原則上可 | 發布前保存下載模型的確切 revision、model card 與 checksum |
| 圖示／圖片／音效／字型 | 第一版不含第三方素材 | 不適用 | 是 | 是 | 未來新增時逐項登記 |
| 外部 API | 第一版沒有雲端推論 API | 不適用 | 是 | 是 | 模型首次下載會連線 Hugging Face |

## 候選基底 Pindrop 的處理

[Pindrop](https://github.com/watzon/pindrop) 在檢查時的版本為 1.19.1、commit `b997399bd1b9d88a64d213369432e2f2d9ddd80f`，根目錄授權為 MIT。法律上可以依 MIT 條款使用與修改，但第一版不直接 fork，理由如下：

1. 專案含 Pindrop 品牌、圖示、翻譯與介面素材，需要全面換掉。
2. 內含 Sparkle 自動更新、AI provider、媒體下載等第一版不需要的網路能力。
3. 內含 FluidAudio；其框架為 Apache-2.0，但不同模型另有各自條款，會擴大模型授權盤點範圍。
4. 它是 macOS 專案；我們需要把純文字整理與語音介面抽成可供未來 iOS／iPadOS 使用的共用核心。

因此只把 Pindrop 當公開技術參考，不複製它的程式或素材。

## Notion 清單的校正

原清單的大方向正確，建議補上以下精度：

1. **無 LICENSE**：預設著作權仍然保留。公開 GitHub repo 依 GitHub 服務條款可被查看、並透過 GitHub 功能 fork，但這不等於取得平台外修改、散布或商用授權。
2. **GPL**：單純內部使用或自行修改通常不要求公開；在散布程式／二進位檔時，才需要依版本條款提供完整對應源碼與相同授權。不是只把幾個修改檔公開就足夠。
3. **AGPL**：除了散布外，修改版讓使用者透過網路互動時也可能觸發提供對應源碼的義務。
4. **Apache-2.0**：除了保留 license/copyright，還要保留適用的 NOTICE、在修改檔案標示變更；授權不授予商標權。
5. **BSD**：要分辨 2-Clause、3-Clause、4-Clause 等實際版本，不能只記「BSD」。
6. **自用**：不是自動豁免著作權與軟體授權，只是通常沒有散布／公開行為；仍要遵守取得來源的條款。
7. **App Store 隱私政策**：Apple 目前要求所有 App Store app 提供可存取的隱私政策，即使宣稱不收集資料，也應清楚說明本機處理、模型下載、保留與刪除方式。
8. **模型與資料集要分開盤點**：框架程式碼、模型權重、訓練資料、轉換後模型可能有不同授權，不可只看 SDK 的 LICENSE。

## 第一版資料流與隱私

1. 使用者按快捷鍵後才開始錄音。
2. 錄音暫存在系統暫存目錄。
3. WhisperKit 在本機轉錄。
4. 文字經本專案的確定性規則整理。
5. 文字放入剪貼簿並貼到目前游標位置。
6. 無論成功或失敗，都刪除暫存錄音。
7. 第一版不建立帳號、不保存錄音、不做 telemetry、不把語音送到雲端。

## 發布前重新檢查

- 產生並隨 App 附帶完整 `Third-Party Notices`。
- 固定所有 Swift Package 與模型 revision，保存 checksum。
- 確認 App 名稱與 icon 不侵犯商標或造成官方關係混淆。
- 準備隱私政策、App Privacy 回答、麥克風用途說明。
- 檢查 iCloud／CloudKit（若啟用）的資料類型、刪除機制與跨裝置同意。
- 實機驗證 App Sandbox、Accessibility、麥克風與 App Store 規則。

### 目前打包備註

`swift-transformers` 內含兩個供其他模型使用的 GPT-2／T5 tokenizer fallback JSON。第一版固定使用 Whisper 模型自己的 tokenizer 設定，因此未將這兩個未使用的 fallback resource bundle 放入手動建立的 macOS App bundle。改由完整 Xcode 專案打包時要重新驗證 Swift Package resource 的放置與簽署。
