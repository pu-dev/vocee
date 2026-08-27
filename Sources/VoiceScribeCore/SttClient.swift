import Foundation

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
    let url = URL(string: "\(trimmedBase)/v1/audio/transcriptions")!

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
