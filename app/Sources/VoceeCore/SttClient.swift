import Foundation

/// Default address of the local MLX whisper server (`dev/run-local`).
public let defaultSttBaseUrl = "http://127.0.0.1:9991"

/// Whisper model size to request from the MLX whisper server. Repo IDs match
/// `mlx-whisper/dev/download-model`.
public enum WhisperModel: String, CaseIterable, Sendable {
  case medium
  case turbo
  case large

  public var displayName: String {
    switch self {
    case .medium: return "Medium"
    case .turbo: return "Turbo"
    case .large: return "Large"
    }
  }

  public var repoId: String {
    switch self {
    case .medium: return "mlx-community/whisper-medium"
    case .turbo: return "mlx-community/whisper-large-v3-turbo"
    case .large: return "mlx-community/whisper-large-v3-mlx"
    }
  }
}

public enum SttError: Error, LocalizedError {
  case badResponse(Int, String)
  case missingText

  public var errorDescription: String? {
    switch self {
    case .badResponse(let status, let body):
      return "Speech-to-text request failed (\(status)): \(body)"
    case .missingText:
      return "Speech-to-text response missing 'text' field"
    }
  }
}

public struct SttClient {
  public var baseUrl: String
  public var model: String
  public var apiKey: String?

  public init(baseUrl: String, model: String, apiKey: String?) {
    self.baseUrl = baseUrl
    self.model = model
    self.apiKey = apiKey
  }

  /// Builds a client from the `STT_BASE_URL` / `STT_MODEL` / `STT_API_KEY`
  /// environment variables, falling back to `baseUrl` / `whisperModel`.
  public static func fromEnvironment(
    baseUrl: String = defaultSttBaseUrl,
    whisperModel: WhisperModel = .large
  ) -> SttClient {
    let env = ProcessInfo.processInfo.environment
    return SttClient(
      baseUrl: env["STT_BASE_URL"] ?? baseUrl,
      model: env["STT_MODEL"] ?? whisperModel.repoId,
      apiKey: env["STT_API_KEY"]
    )
  }

  public func transcribe(wav: Data, filename: String = "recording.wav") async throws -> String {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()

    func appendField(_ name: String, _ value: String) {
      body.append("--\(boundary)\r\n".data(using: .utf8)!)
      body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
      body.append("\(value)\r\n".data(using: .utf8)!)
    }

    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append(
      "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
        .data(using: .utf8)!)
    body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
    body.append(wav)
    body.append("\r\n".data(using: .utf8)!)

    appendField("model", model)
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    let trimmedBase = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
    let url = URL(string: "\(trimmedBase)/api/stt")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    if let apiKey, !apiKey.isEmpty {
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SttError.badResponse(-1, "no HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
      throw SttError.badResponse(http.statusCode, String(data: data, encoding: .utf8) ?? "")
    }

    struct TranscriptionResponse: Decodable { let text: String? }
    let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    guard let text = decoded.text else { throw SttError.missingText }
    return text
  }
}
