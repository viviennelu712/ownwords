import Testing
@testable import VoiceInputCore

struct TranscriptPunctuatorTests {
    private let punctuator = TranscriptPunctuator()

    @Test func addsCommaAndPeriodFromPauses() {
        let words = [
            TimedTranscriptWord(text: "今天我們", start: 0.0, end: 0.8),
            TimedTranscriptWord(text: "先試第一件事", start: 1.2, end: 2.2),
            TimedTranscriptWord(text: "然後再測第二件事", start: 3.6, end: 4.9),
        ]

        #expect(punctuator.punctuate(words: words, fallbackText: "") == "今天我們，先試第一件事。然後再測第二件事。")
    }

    @Test func preservesExistingPunctuation() {
        let words = [
            TimedTranscriptWord(text: "這樣可以嗎？", start: 0.0, end: 0.8),
            TimedTranscriptWord(text: "可以！", start: 1.8, end: 2.3),
        ]

        #expect(punctuator.punctuate(words: words, fallbackText: "") == "這樣可以嗎？可以！")
    }

    @Test func upgradesCommaAfterLongPause() {
        let words = [
            TimedTranscriptWord(text: "第一句，", start: 0.0, end: 0.7),
            TimedTranscriptWord(text: "第二句", start: 2.1, end: 2.8),
        ]

        #expect(punctuator.punctuate(words: words, fallbackText: "") == "第一句。第二句。")
    }

    @Test func guaranteesFinalPunctuationWhenTimestampsAreUnavailable() {
        #expect(punctuator.punctuate(words: [], fallbackText: "這是一句沒有標點的話") == "這是一句沒有標點的話。")
        #expect(punctuator.punctuate(words: [], fallbackText: "hello") == "hello")
    }

    @Test func removesWhisperControlTokens() {
        let words = [
            TimedTranscriptWord(text: "<|0.00|>這是第一句", start: 0.0, end: 0.8),
            TimedTranscriptWord(text: "<|2.20|>這是第二句", start: 2.2, end: 3.2),
        ]

        #expect(punctuator.punctuate(words: words, fallbackText: "") == "這是第一句。這是第二句。")
    }

    @Test func usesCommaAfterContinuationWordEvenForLongPause() {
        let words = [
            TimedTranscriptWord(text: "因為", start: 0.0, end: 0.5),
            TimedTranscriptWord(text: "我還沒說完", start: 1.5, end: 2.5),
        ]

        #expect(punctuator.punctuate(words: words, fallbackText: "") == "因為，我還沒說完。")
    }
}
