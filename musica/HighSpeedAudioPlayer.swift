//
//  HighSpeedAudioPlayer.swift
//  musica
//
//  AVAudioPlayer の drop-in 置換。
//
//  ■ エンジン構成
//    playerNode → timePitch → varispeed → mainMixerNode
//    ・≤ 8x  : timePitch のみ（ピッチ保持）
//    ・> 8x  : timePitch 8x 固定 + varispeed で追加倍速（ピッチが varispeed 分だけ上昇）
//    ・上限  : timePitch 8x × varispeed 6.25x = 50x
//
//  ■ 完了通知
//    _pendingCompletionsToIgnore（カウンター）の代わりに _generation（世代番号）を使用。
//    stop/seek/rateChange のたびに世代番号をインクリメント。
//    scheduleSegment のクロージャは生成時の世代番号をキャプチャし、
//    番号が変わっていたら何もしない。これにより count の過不足による
//    「次曲完了を無視する」バグを根絶する。
//

import AVFoundation

final class HighSpeedAudioPlayer {

    // MARK: - Engine

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch  = AVAudioUnitTimePitch()   // ピッチ保持、最大 8x
    private let varispeed  = AVAudioUnitVarispeed()   // 8x 超の追加倍速用（最大 6.25x → 合計 50x）

    // MARK: - Source

    private let fileURL:   URL
    private var audioFile: AVAudioFile

    // MARK: - State

    private var _rate: Float = 1.0
    private var _seekOffset:    TimeInterval = 0
    private var _playStartDate: Date?
    private var _pausePosition: TimeInterval?
    private var _segmentScheduled = false
    private var _loopsRemaining:  Int = 0

    /// stop / seek / rate変更 のたびにインクリメント。
    /// scheduleSegment のクロージャが生成時の世代番号と一致しない場合は無視する。
    private var _generation = 0

    // MARK: - Public API (AVAudioPlayer 互換)

    /// 後方互換のために残す。完了通知は onFinish を使うこと。
    weak var delegate: AVAudioPlayerDelegate?

    /// 自然に再生が終了したときに呼ばれる。
    var onFinish: (() -> Void)?

    var enableRate: Bool = true
    var numberOfLoops: Int = 0

    var volume: Float = 1.0 {
        didSet { playerNode.volume = volume }
    }

    var rate: Float {
        get { _rate }
        set {
            let wasPlaying = isPlaying
            let pos        = currentTime   // _rate 変更前に確定

            applyRate(newValue)            // _rate / timePitch / varispeed を更新

            // 世代を進めて旧 completion を無効化し、新レートで再スケジュール
            _generation += 1
            playerNode.stop()
            _seekOffset = pos
            _segmentScheduled = false
            scheduleSegment(from: pos)

            if wasPlaying {
                _pausePosition = nil
                _playStartDate = Date()
                playerNode.play()
            } else {
                _pausePosition = pos
            }
        }
    }

    var duration: TimeInterval {
        Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }

    var isPlaying: Bool {
        playerNode.isPlaying && _pausePosition == nil
    }

    var currentTime: TimeInterval {
        get {
            if let p = _pausePosition { return p }
            guard let startDate = _playStartDate else { return _seekOffset }
            let elapsed = Date().timeIntervalSince(startDate) * Double(_rate)
            return min(_seekOffset + elapsed, duration)
        }
        set {
            let wasPlaying = isPlaying
            _seekOffset    = max(0, min(newValue, duration))
            _pausePosition = wasPlaying ? nil : _seekOffset
            _generation   += 1
            playerNode.stop()
            _segmentScheduled = false
            scheduleSegment(from: _seekOffset)
            if wasPlaying { _ = play() }
        }
    }

    // MARK: - Init

    init(contentsOf url: URL) throws {
        self.fileURL   = url
        self.audioFile = try AVAudioFile(forReading: url)
        setupEngine()
    }

    // MARK: - Playback

    @discardableResult
    func prepareToPlay() -> Bool {
        guard startEngineIfNeeded() else { return false }
        if !_segmentScheduled { scheduleSegment(from: _seekOffset) }
        return true
    }

    @discardableResult
    func play() -> Bool {
        guard startEngineIfNeeded() else { return false }
        if !_segmentScheduled { scheduleSegment(from: _seekOffset) }
        let isResuming = _pausePosition != nil
        _pausePosition = nil
        if !isResuming { _loopsRemaining = numberOfLoops }
        _playStartDate = Date()
        playerNode.play()
        return true
    }

    func pause() {
        let pos = currentTime
        _pausePosition = pos
        _seekOffset    = pos
        _playStartDate = nil
        playerNode.pause()
    }

    func stop() {
        let pos = currentTime
        _generation += 1
        playerNode.stop()
        _seekOffset       = pos
        _pausePosition    = nil
        _playStartDate    = nil
        _segmentScheduled = false
    }

    // MARK: - Private

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(varispeed)
        let sr  = audioFile.processingFormat.sampleRate
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        // playerNode → timePitch → varispeed → mainMixerNode
        // timePitch が 8x まではピッチ保持。それを超える分を varispeed が担う。
        engine.connect(playerNode, to: timePitch,            format: fmt)
        engine.connect(timePitch,  to: varispeed,            format: fmt)
        engine.connect(varispeed,  to: engine.mainMixerNode, format: fmt)
        playerNode.volume = volume
        applyRate(1.0)
    }

    /// ≤ 8x : timePitch のみ（ピッチ保持）
    /// > 8x : timePitch = 8x 固定、varispeed = speed/8（最大 6.25x → 合計 50x）
    private func applyRate(_ speed: Float) {
        if speed <= 8.0 {
            let clamped = max(1.0 / 32.0, speed)
            timePitch.rate = clamped
            varispeed.rate = 1.0
            _rate = clamped
        } else {
            let vs = min(speed / 8.0, 6.25)   // 上限 50x (8 × 6.25)
            timePitch.rate = 8.0
            varispeed.rate = vs
            _rate = 8.0 * vs
        }
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func scheduleSegment(from time: TimeInterval) {
        let sr         = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sr)
        let total      = audioFile.length
        guard startFrame < total else { return }
        let frames     = AVAudioFrameCount(total - startFrame)
        let gen        = _generation   // このクロージャの世代番号をキャプチャ
        _segmentScheduled = true
        playerNode.scheduleSegment(audioFile,
                                   startingFrame: startFrame,
                                   frameCount: frames,
                                   at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self._generation == gen else { return }
                self.didFinishSegment()
            }
        }
    }

    private func didFinishSegment() {
        _segmentScheduled = false
        _playStartDate    = nil
        if _loopsRemaining != 0 {
            if _loopsRemaining > 0 { _loopsRemaining -= 1 }
            _seekOffset = 0
            scheduleSegment(from: 0)
            _playStartDate = Date()
        } else {
            onFinish?()
        }
    }
}
