import AVFoundation
import Foundation

public final class AudioRecorder {
  private let engine = AVAudioEngine()
  private var converter: AVAudioConverter?
  private let targetFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

  public private(set) var pcmData = Data()
  public var onLevel: ((Float) -> Void)?

  /// Maps a peak Int16 sample to 0...1 on a dB scale so normal speech fills
  /// the meter instead of only ever reaching a small fraction of it.
  private static let noiseFloorDb: Float = -50

  public init() {}

  public static func normalizedLevel(forPeak peak: Int16) -> Float {
    guard peak > 0 else { return 0 }
    let amplitude = Float(peak) / Float(Int16.max)
    let db = 20 * log10(amplitude)
    let normalized = (db - noiseFloorDb) / (0 - noiseFloorDb)
    return min(1, max(0, normalized))
  }

  public func start() throws {
    pcmData.removeAll()

    let input = engine.inputNode
    let inputFormat = input.outputFormat(forBus: 0)
    converter = AVAudioConverter(from: inputFormat, to: targetFormat)

    input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
      self?.process(buffer: buffer)
    }

    engine.prepare()
    try engine.start()
  }

  public func stop() -> Data {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    return pcmData
  }

  private func process(buffer: AVAudioPCMBuffer) {
    guard let converter else { return }

    let outCapacity = AVAudioFrameCount(
      Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate + 16)
    guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity)
    else { return }

    var error: NSError?
    converter.convert(to: outBuffer, error: &error) { _, outStatus in
      outStatus.pointee = .haveData
      return buffer
    }
    if error != nil { return }

    guard let channelData = outBuffer.int16ChannelData else { return }
    let frameCount = Int(outBuffer.frameLength)
    let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)

    pcmData.append(contentsOf: samples.withMemoryRebound(to: UInt8.self) { Array($0) })

    var peak: Int16 = 0
    for s in samples {
      let a = abs(s)
      if a > peak { peak = a }
    }
    let level = Self.normalizedLevel(forPeak: peak)
    DispatchQueue.main.async { [weak self] in
      self?.onLevel?(level)
    }
  }

  public func encodeWav(pcm: Data) -> Data {
    let sampleRate: UInt32 = 16000
    let bitsPerSample: UInt16 = 16
    let channels: UInt16 = 1
    let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
    let blockAlign = channels * (bitsPerSample / 8)

    var header = Data()
    header.append(contentsOf: Array("RIFF".utf8))
    header.append(littleEndian: UInt32(36 + pcm.count))
    header.append(contentsOf: Array("WAVE".utf8))
    header.append(contentsOf: Array("fmt ".utf8))
    header.append(littleEndian: UInt32(16))
    header.append(littleEndian: UInt16(1)) // PCM
    header.append(littleEndian: channels)
    header.append(littleEndian: sampleRate)
    header.append(littleEndian: byteRate)
    header.append(littleEndian: blockAlign)
    header.append(littleEndian: bitsPerSample)
    header.append(contentsOf: Array("data".utf8))
    header.append(littleEndian: UInt32(pcm.count))

    return header + pcm
  }
}

extension Data {
  mutating func append(littleEndian value: UInt32) {
    var v = value.littleEndian
    Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
  }
  mutating func append(littleEndian value: UInt16) {
    var v = value.littleEndian
    Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
  }
}
