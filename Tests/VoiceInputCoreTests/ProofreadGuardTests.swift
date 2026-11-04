import Testing
@testable import VoiceInputCore

struct ProofreadGuardTests {
    private let guardrail = ProofreadGuard()

    @Test func acceptsFixingAFewWrongCharacters() {
        #expect(guardrail.accepts(
            original: "才聊已經標在展示牌上，接著把NoterbookLM的範例資料放到藍色盒子。",
            proofread: "材料已經標在展示牌上，接著把NotebookLM的範例資料放到藍色盒子。"
        ))
    }

    @Test func acceptsPunctuationOnlyChanges() {
        #expect(guardrail.accepts(original: "色票排好了嗎。藍色樣本還沒展示", proofread: "色票排好了嗎？藍色樣本還沒展示。"))
    }

    @Test func rejectsPolishedRewrite() {
        #expect(!guardrail.accepts(
            original: "就是我覺得那個這個展示架它就是會一直把色票排得很密集然後我就覺得不好辨認",
            proofread: "展示架上的色票排列過於密集，難以辨認。"
        ))
    }

    @Test func rejectsDroppingFillersAndRepeats() {
        #expect(!guardrail.accepts(
            original: "然後然後就是我覺得我覺得那個可以先排藍色，對，就是先排藍色",
            proofread: "我覺得可以先排藍色。"
        ))
    }

    @Test func allowsMoreChangeWhenSpeakerCorrectsThemself() {
        #expect(guardrail.accepts(original: "色票分三格，不對，四格，每格都放藍色", proofread: "色票分四格，每格都放藍色"))
    }

    @Test func rejectsEmptyOrMuchLongerOutput() {
        #expect(!guardrail.accepts(original: "好啊", proofread: ""))
        #expect(!guardrail.accepts(original: "好啊", proofread: "好啊，展示架上還可以放置更多不同顏色的樣本，並且逐一加上詳細標籤。"))
    }
}
