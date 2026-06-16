import FluidAudio
import Foundation

/// Native Swift transcription backend for FunASR's SenseVoiceSmall via FluidAudio.
actor SenseVoiceTranscriber {
    private var manager: SenseVoiceManager?

    enum TranscriberError: Error, LocalizedError {
        case notLoaded

        var errorDescription: String? {
            switch self {
            case .notLoaded:
                return "SenseVoice models not loaded. Call loadModels() first."
            }
        }
    }

    /// Downloads models if needed and initializes the SenseVoice manager.
    func loadModels(progress: ((Double, String?) -> Void)? = nil) async throws {
        if manager != nil { return }

        fputs("[sensevoice] downloading/loading models...\n", stderr)
        let loaded = try await SenseVoiceManager.load(precision: .fp16) { downloadProgress in
            DispatchQueue.main.async {
                switch downloadProgress.phase {
                case .listing:
                    progress?(downloadProgress.fractionCompleted, "Preparing SenseVoice download...")
                case .downloading(_, _):
                    progress?(downloadProgress.fractionCompleted, "Downloading SenseVoice...")
                case .compiling(_):
                    progress?(downloadProgress.fractionCompleted, "Compiling SenseVoice...")
                }
            }
        }
        self.manager = loaded
        fputs("[sensevoice] models ready\n", stderr)
    }

    func transcribe(wavURL: URL) async throws -> (text: String, processingTime: Double) {
        guard let manager else { throw TranscriberError.notLoaded }
        let start = CFAbsoluteTimeGetCurrent()
        let text = try await manager.transcribe(audioURL: wavURL)
        let processingTime = CFAbsoluteTimeGetCurrent() - start
        return (text, processingTime)
    }

    func shutdown() {
        manager = nil
    }

    static func isModelDownloaded() -> Bool {
        let supportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FluidAudio/Models/sensevoice-small-coreml")
        return SenseVoiceModels.modelsExist(at: supportDir, precision: .fp16)
    }
}
