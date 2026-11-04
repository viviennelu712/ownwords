import Testing
@testable import VoiceInputCore

struct TranscriptMergerTests {
    private let merger = TranscriptMerger()

    @Test func skipsIdenticalResults() {
        #expect(merger.merge(["這是一段測試。", "這是一段測試。"]) == "這是一段測試。")
    }

    @Test func removesOverlapBetweenChunks() {
        #expect(merger.merge(["今天我們要討論三件事情", "三件事情，第一件是時間。"]) == "今天我們要討論三件事情，第一件是時間。")
    }

    @Test func removesOverlapAcrossGuaranteedChunkPeriod() {
        #expect(merger.merge(["今天我們要討論三件事情。", "三件事情，第一件是時間。"]) == "今天我們要討論三件事情，第一件是時間。")
    }
}
