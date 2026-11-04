import Testing
@testable import VoiceInputCore

/// Synthetic regression cases for the first-week fixes.
struct WeekOneFixesTests {
    private let cleaner = TranscriptCleaner()
    private let filter = HallucinationFilter()

    @Test func removesTrailingSignOffs() {
        #expect(filter.clean("紅色樣本已經完成。謝謝大家。") == "紅色樣本已經完成。")
        #expect(filter.clean("展示完成，感謝觀看。") == "展示完成。")
        #expect(filter.clean("樣本完成。請不吝點贊 訂閱 轉發 打賞支持明鏡與點點欄目") == "樣本完成。")
        #expect(filter.clean("謝謝大家。") == "")
    }

    @Test func keepsSignOffSaidMidSentence() {
        #expect(filter.clean("範例台詞是謝謝大家參觀色票展示。") == "範例台詞是謝謝大家參觀色票展示。")
    }

    @Test func cleanerDropsSignOffAfterOtherFixes() {
        #expect(cleaner.clean("蓝色盒子已经放到展示架上。谢谢大家。") == "藍色盒子已經放到展示架上。")
    }

    @Test func questionParticlesGetQuestionMarks() {
        #expect(cleaner.clean("色票排好了嗎。") == "色票排好了嗎？")
        #expect(cleaner.clean("是紅藍色票一起放對不對。好。") == "是紅藍色票一起放對不對？好。")
        #expect(cleaner.clean("展示架要放在哪裡呢。") == "展示架要放在哪裡呢？")
        #expect(cleaner.clean("色票還在印呢。") == "色票還在印呢。")
    }

    @Test func halfSentencePeriodBecomesComma() {
        #expect(cleaner.clean("先展示這個。藍色的樣本放旁邊。") == "先展示這個，藍色的樣本放旁邊。")
        #expect(cleaner.clean("樣本是。用紙板製成的。") == "樣本是，用紙板製成的。")
    }

    @Test func clearsDotsLeftWhileThinking() {
        #expect(cleaner.clean("請選擇。..。藍色色票") == "請選擇⋯藍色色票")
    }

    @Test func taiwanWordForms() {
        #expect(cleaner.clean("样本录制完成，删除重复的标签，按准则排序，查看盒子里那则说明") == "樣本錄製完成，刪除重複的標籤，按準則排序，查看盒子裡那則說明")
    }

    @Test func fullWidthQuestionMarkAfterEnglishWord() {
        #expect(cleaner.clean("色票展示有deadline?") == "色票展示有deadline？")
        #expect(cleaner.clean("Is this OK?") == "Is this OK?")
    }

    @Test func moreTaiwanLiAndTrailingHesitation() {
        #expect(cleaner.clean("展示盒子里有藍色色票") == "展示盒子裡有藍色色票")
        #expect(cleaner.clean("地圖標出三公里，圖例列出里長") == "地圖標出三公里，圖例列出里長")
        #expect(cleaner.clean("藍色色票排好了嗯。") == "藍色色票排好了。")
    }

    @Test func cleanerRemovesRestart() {
        #expect(cleaner.clean("請先展示藍色色票。不要太亮。不要把它調太亮。") == "請先展示藍色色票。不要把它調太亮。")
    }

    @Test func paragraphBreaksFromTidyingSurviveCleanup() {
        #expect(cleaner.clean("這個色票排得太密，你看得清楚嗎？\n\n下午我再去買展示架。")
            == "這個色票排得太密，你看得清楚嗎？\n\n下午我再去買展示架。")
    }
}
