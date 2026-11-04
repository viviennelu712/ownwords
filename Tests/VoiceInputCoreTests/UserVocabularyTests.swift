import Testing
@testable import VoiceInputCore

struct UserVocabularyTests {
    @Test func parsesArrowsAndSkipsComments() {
        let vocabulary = UserVocabulary(fileContents: """
        # 我的詞庫
        花屏 → 花瓶
        Cloud Code -> Claude Code

        沒有箭頭的行會被略過
        花瓶 => 花瓶
        """)
        #expect(vocabulary.rules.count == 2)
    }

    @Test func replacesChineseInsideSentence() {
        let vocabulary = UserVocabulary(fileContents: "花屏 → 花瓶")
        #expect(vocabulary.correct("展示台上的花屏是藍色的。") == "展示台上的花瓶是藍色的。")
    }

    @Test func englishMatchesWholeWordsCaseInsensitively() {
        let vocabulary = UserVocabulary(fileContents: "cloud code → Claude Code")
        #expect(vocabulary.correct("我用Cloud Code做的") == "我用Claude Code做的")
        #expect(vocabulary.correct("Cloud Codes") == "Cloud Codes")
    }

    @Test func replacementIsNeverMatchedAgain() {
        let vocabulary = UserVocabulary(fileContents: """
        Cloud → Claude
        Cloud Storage → Cloud Storage 雲端
        """)
        #expect(vocabulary.correct("Cloud Storage跟Cloud") == "Cloud Storage 雲端跟Claude")
    }

    @Test func replacementTextIsLiteral() {
        let vocabulary = UserVocabulary(fileContents: "價錢 → $100")
        #expect(vocabulary.correct("價錢") == "$100")
    }
}
