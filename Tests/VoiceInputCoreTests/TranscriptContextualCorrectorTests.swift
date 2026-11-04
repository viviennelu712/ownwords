import Testing
@testable import VoiceInputCore

struct TranscriptContextualCorrectorTests {
    private let corrector = TranscriptContextualCorrector()

    @Test func repairsRepeatedBridgeWordAcrossFalseBoundary() {
        #expect(corrector.correct("從色票到。到展示樣本") == "從色票到展示樣本")
        #expect(corrector.correct("先分類，然後。然後貼標籤") == "先分類，然後貼標籤")
    }

    @Test func downgradesBoundaryAfterContinuationWord() {
        #expect(corrector.correct("因為。這邊還沒說完") == "因為，這邊還沒說完")
        #expect(corrector.correct("這件事已經說完。下一件事") == "這件事已經說完。下一件事")
    }

    @Test func collapsesDuplicatedDiscourseMarker() {
        #expect(corrector.correct("就是就是藍色色票") == "就是藍色色票")
        #expect(corrector.correct("我覺得，我覺得可以") == "我覺得可以")
    }
}
