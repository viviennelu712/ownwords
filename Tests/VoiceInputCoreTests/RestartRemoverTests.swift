import Testing
@testable import VoiceInputCore

struct RestartRemoverTests {
    private let remover = RestartRemover()

    @Test func keepsOnlyTheSecondAttempt() {
        // Synthetic clauses with the same restart structure.
        #expect(remover.clean("請先放到，展示架上。不要太亮。不要把它調太亮。色彩確認之後再記錄結果。")
            == "請先放到，展示架上。不要把它調太亮。色彩確認之後再記錄結果。")
        #expect(remover.clean("這個色票。這個色票很清楚。") == "這個色票很清楚。")
    }

    @Test func leavesEmphasisAndDifferentSentencesAlone() {
        #expect(remover.clean("很好。很好很好。") == "很好。很好很好。")
        #expect(remover.clean("先放紅色積木。然後再放藍色積木。") == "先放紅色積木。然後再放藍色積木。")
        #expect(remover.clean("對，對對對，就是這樣。") == "對，對對對，就是這樣。")
    }

    @Test func doesNotDropAShortClauseBeforeALongUnrelatedOne() {
        #expect(remover.clean("我認為，這批展示用的色票要等全部編完號才能進行分類。")
            == "我認為，這批展示用的色票要等全部編完號才能進行分類。")
    }
}
