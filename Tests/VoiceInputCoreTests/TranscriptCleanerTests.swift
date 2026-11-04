import Testing
@testable import VoiceInputCore

struct TranscriptCleanerTests {
    private let cleaner = TranscriptCleaner()

    @Test func trimsWhitespaceAndLeadingFiller() {
        // Preserve lexical fillers such as 「那個」; remove only hesitation sounds.
        #expect(cleaner.clean("  嗯，那個，色票已經排好了。  ") == "那個，色票已經排好了。")
    }

    @Test func removesFillerAfterPunctuation() {
        #expect(cleaner.clean("第一點，嗯，準備資料。第二點，呃，確認時間。") == "第一點，準備資料。第二點，確認時間。")
    }

    @Test func doesNotRemoveMeaningfulMiddlePhrase() {
        #expect(cleaner.clean("這就是說明文件。") == "這就是說明文件。")
    }

    @Test func normalizesPunctuationSpacingAndBlankLines() {
        #expect(cleaner.clean("你好 ，  世界。\n\n\n下一段") == "你好，世界。\n\n下一段")
    }

    @Test func removesSubtitleHallucinationAndConvertsTraditionalChinese() {
        #expect(cleaner.clean("这个工具可以用。(字幕君)") == "這個工具可以用。")
    }

    @Test func collapsesExactlyDuplicatedTranscript() {
        #expect(cleaner.clean("這段文字重複一次。這段文字重複一次。") == "這段文字重複一次。")
    }

    @Test func convertsChineseHalfWidthPunctuation() {
        #expect(cleaner.clean("這是一段話,下一段呢?很好!") == "這是一段話，下一段呢？很好！")
        #expect(
            cleaner.clean("範例文件使用Notebook LM,也使用GPT。圖片存到Cloud Storage,方便展示。")
                == "範例文件使用NotebookLM，也使用GPT。圖片存到Cloud Storage，方便展示。"
        )
    }

    @Test func cleansSyntheticNotebookLMTranscriptWithoutParaphrasing() {
        let raw = "展示資料使用Norbo LM整理，範例又用GPT又用Cloud。就是都在NOBOOK LM裡面查看從色票到。到展示樣本。"
        let cleaned = cleaner.clean(raw)

        #expect(cleaned.contains("NotebookLM"))
        #expect(cleaned.contains("GPT又用Claude"))
        #expect(cleaned.contains("色票到展示樣本"))
        #expect(!cleaned.contains("Norbo"))
        #expect(!cleaned.contains("NOBOOK"))
        #expect(!cleaned.contains("到。到"))
    }

    @Test func usesTaiwanVariantOfLi() {
        let cleaner = TranscriptCleaner()
        #expect(cleaner.clean("标签就放在蓝色盒子里。") == "標籤就放在藍色盒子裡。")
        #expect(cleaner.clean("这里面有三公里。") == "這裡面有三公里。")
    }
}
