import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechRecognitionService {

    enum AuthStatus {
        case notDetermined, authorized, denied, restricted
    }

    private(set) var isListening = false
    private(set) var authStatus: AuthStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onSpeechDetected: (() -> Void)?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            let micGranted = await AVAudioApplication.requestRecordPermission()
            authStatus = micGranted ? .authorized : .denied
        case .denied:   authStatus = .denied
        case .restricted: authStatus = .restricted
        default:        authStatus = .notDetermined
        }
    }

    func startListening() throws {
        guard !isListening else { return }
        guard authStatus == .authorized else { return }
        guard let recognizer, recognizer.isAvailable else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result, !result.bestTranscription.formattedString.isEmpty {
                self.onSpeechDetected?()
            }
            if error != nil || (result?.isFinal == true) {
                self.stopListening()
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
