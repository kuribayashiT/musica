//
//  HighSpeedAudioPlayer.swift
//  musica
//
//  AVAudioPlayer の drop-in 置換。
//  AVAudioEngine + AVAudioUnitTimePitch + AVAudioUnitVarispeed を組み合わせ、
//  最大 ~256x (実用上 50x) の速度変更をサポート。
//
//  速度配分:
//    speed ≤ 32x → timePitch のみ (ピッチ保持)
//    speed > 32x → timePitch@32x + varispeed で残りを補う (最大 32×8 = 256x)
//

import AVFoundation

final class HighSpeedAudioPlayer {

    // MARK: - Engine

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch  = AVAudioUnitTimePitch()   // ピッチ保持、最大 32x
    private let varispeed  = AVAudioUnitVarispeed()   // ピッチ変化あり、最大 8x

    // MARK: - Source

    private let fileURL:   URL
    private var audioFile: AVAudioFile
    // delegate callback 用の AVAudioPlayer ダミー（delegate が player 引数を使わないため）
    private lazy var _dummyPlayer: AVAudioPlayer? = try? AVAudioPlayer(contentsOf: fileURL)

    // MARK: - State

    private var _rate: Float = 1.0
    private var _seekOffset:    TimeInterval = 0   // 現在セグメントを開始した時点のファイル位置
    private var _playStartDate: Date?              // play 開始時点の壁時計
    private var _pausePosition: TimeInterval?      // 非 nil = 一時停止中
    private var _segmentScheduled = false
    private var _loopsRemaining:  Int = 0

    // MARK: - Public (AVAudioPlayer 互換 API)

    weak var delegate: AVAudioPlayerDelegate?

    /// no-op — HighSpeedAudioPlayer は常に速度変更をサポートする
    var enableRate: Bool = true

    var numberOfLoops: Int = 0

    var volume: Float = 1.0 {
        didSet { playerNode.volume = volume }
    }

    var rate: Float {
        get { _rate }
        set { _rate = newValue; applyRate(newValue) }
    }

    var duration: TimeInterval {
        Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }

    var isPlaying: Bool {
        playerNode.isPlaying && _pausePosition == nil
    }

    /// ファイル内の現在再生位置（秒）
    var currentTime: TimeInterval {
        get {
            if let p = _pausePosition { return p }
            guard let startDate = _playStartDate else { return _seekOffset }
            let elapsed = Date().timeIntervalSince(startDate) * Double(_rate)
            return min(_seekOffset + elapsed, duration)
        }
        set {
            let wasPlaying = isPlaying
            _seekOffset = max(0, min(newValue, duration))
            _pausePosition = wasPlaying ? nil : _seekOffset
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
        let pos = currentTime   // _playStartDate をクリアする前に計算
        _pausePosition = pos
        _seekOffset    = pos    // 再開後の currentTime 計算のために更新
        _playStartDate = nil
        playerNode.pause()
    }

    func stop() {
        playerNode.stop()
        _seekOffset       = 0
        _pausePosition    = nil
        _playStartDate    = nil
        _segmentScheduled = false
    }

    // MARK: - Private

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(varispeed)
        let fmt = audioFile.processingFormat
        engine.connect(playerNode, to: timePitch,          format: fmt)
        engine.connect(timePitch,  to: varispeed,          format: nil)
        engine.connect(varispeed,  to: engine.mainMixerNode, format: nil)
        playerNode.volume = volume
        applyRate(1.0)
    }

    // speed ≤ 32x : timePitch のみ（ピッチ保持）
    // speed > 32x : timePitch を 32x に固定し、varispeed で残りを補う
    private func applyRate(_ speed: Float) {
        if speed <= 32.0 {
            timePitch.rate = max(1.0 / 32.0, speed)
            varispeed.rate = 1.0
        } else {
            timePitch.rate = 32.0
            varispeed.rate = min(8.0, speed / 32.0)
        }
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do { try engine.start(); return true }
        catch { return false }
    }

    private func scheduleSegment(from time: TimeInterval) {
        let sr         = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sr)
        let total      = audioFile.length
        guard startFrame < total else { return }
        let frames     = AVAudioFrameCount(total - startFrame)
        _segmentScheduled = true
        playerNode.scheduleSegment(audioFile,
                                   startingFrame: startFrame,
                                   frameCount: frames,
                                   at: nil) { [weak self] in
            DispatchQueue.main.async { self?.didFinishSegment() }
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
            if let dummy = _dummyPlayer {
                delegate?.audioPlayerDidFinishPlaying?(dummy, successfully: true)
            }
        }
    }
}
