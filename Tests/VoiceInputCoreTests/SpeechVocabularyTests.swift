import Testing
@testable import VoiceInputCore

struct SpeechVocabularyTests {
    private let vocabulary = SpeechVocabulary()

    @Test func normalizesNotebookLMVariants() {
        #expect(vocabulary.correct("展示資料來自Norbo LM") == "展示資料來自NotebookLM")
        #expect(vocabulary.correct("範例色票放在NOBOOK LM裡") == "範例色票放在NotebookLM裡")
        #expect(vocabulary.correct("放在Note Book LM裡") == "放在NotebookLM裡")
    }

    @Test func correctsClaudeOnlyInToolContext() {
        #expect(vocabulary.correct("範例又用GPT又用Cloud") == "範例又用GPT又用Claude")
        #expect(vocabulary.correct("用GPT或Cloud來整理") == "用GPT或Claude來整理")
    }

    @Test func preservesRealCloudReferences() {
        #expect(vocabulary.correct("把檔案放到Cloud Storage") == "把檔案放到Cloud Storage")
        #expect(vocabulary.correct("GPT部署在Cloud Storage") == "GPT部署在Cloud Storage")
    }

    @Test func normalizesSpacedGPT() {
        #expect(vocabulary.correct("用G P T回答") == "用GPT回答")
        #expect(vocabulary.correct("打開Chat GPT") == "打開ChatGPT")
    }
}
