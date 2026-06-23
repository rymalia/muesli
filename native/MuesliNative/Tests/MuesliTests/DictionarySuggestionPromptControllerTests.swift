import Testing
@testable import MuesliNativeApp

@Suite("DictionarySuggestionPromptController")
struct DictionarySuggestionPromptControllerTests {
    @Test("Auto-dismiss callback is skipped when hover pauses during fade-out")
    @MainActor
    func autoDismissCallbackSkippedWhenPausedDuringFadeOut() {
        #expect(DictionarySuggestionPromptController.firesAutoDismissCallbackAfterFade(wasDismissPaused: false))
        #expect(!DictionarySuggestionPromptController.firesAutoDismissCallbackAfterFade(wasDismissPaused: true))
    }
}
