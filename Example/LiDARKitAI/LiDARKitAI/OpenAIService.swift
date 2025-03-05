import Foundation

class OpenAIService {
    
    enum OpenAIError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError
        case apiError(String)
        case missingAPIKey
        case networkError(Error)
        case invalidResponse(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received from API"
            case .decodingError:
                return "Failed to decode API response"
            case .apiError(let message):
                return "API Error: \(message)"
            case .missingAPIKey:
                return "OpenAI API key is missing or invalid. Please check your ApiKeys.plist file."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let statusCode):
                return "Invalid response from server (Status: \(statusCode))"
            }
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
    }
    
    struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        
        let choices: [Choice]
        let error: ErrorResponse?
    }
    
    struct ErrorResponse: Codable {
        let message: String
    }
    
    static func sendMessage(messages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        // Validate API key
        let apiKey = Config.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("API Key from Config: \(apiKey.isEmpty ? "Empty" : "Not empty, length: \(apiKey.count)")")
        
        // Check if the API key starts with "sk-" which is the expected format
        if !apiKey.hasPrefix("sk-") {
            print("Warning: API key does not start with 'sk-', which is the expected format for OpenAI API keys")
        } else {
            print("API key has correct prefix: sk-")
            
            // Check if it's a project API key (sk-proj-) which is also valid
            if apiKey.hasPrefix("sk-proj-") {
                print("API key is a project API key (sk-proj-), which is valid")
            }
        }
        
        guard !apiKey.isEmpty else {
            print("OpenAI API Key is missing or empty")
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        print("Using API key with length: \(apiKey.count) characters")
        
        guard let url = URL(string: Config.openAIEndpoint) else {
            print("Invalid OpenAI endpoint URL: \(Config.openAIEndpoint)")
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        let request = ChatRequest(
            model: Config.defaultModelName,
            messages: messages,
            max_tokens: Config.maxTokens
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Print the request headers for debugging (hiding the full API key)
        let headers = urlRequest.allHTTPHeaderFields ?? [:]
        let sanitizedHeaders = headers.mapValues { value in
            if value.hasPrefix("Bearer ") {
                return "Bearer sk-****"
            }
            return value
        }
        print("Request headers: \(sanitizedHeaders)")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("Sending request to OpenAI API with model: \(Config.defaultModelName), max tokens: \(Config.maxTokens)")
            
            // Print the request body for debugging
            if let httpBody = urlRequest.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
                print("Request body: \(bodyString)")
            }
        } catch {
            print("Failed to encode request: \(error)")
            completion(.failure(OpenAIError.networkError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(OpenAIError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                completion(.failure(OpenAIError.invalidResponse(0)))
                return
            }
            
            print("OpenAI API response status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("No data received from API")
                completion(.failure(OpenAIError.noData))
                return
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw API response: \(responseString)")
            }
            
            // If we get an error status code, try to parse the error message
            if httpResponse.statusCode >= 400 {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            print("API Error: \(message)")
                            
                            // Check for specific error messages
                            if message.contains("API key") || message.contains("authentication") {
                                print("This appears to be an API key issue")
                                completion(.failure(OpenAIError.missingAPIKey))
                            } else {
                                completion(.failure(OpenAIError.apiError(message)))
                            }
                            return
                        } else {
                            // If we can't extract a specific error message
                            let errorMessage = "HTTP Error \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                            print(errorMessage)
                            completion(.failure(OpenAIError.invalidResponse(httpResponse.statusCode)))
                            return
                        }
                    }
                } catch {
                    print("Failed to parse error response: \(error)")
                    let errorMessage = "HTTP Error \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(OpenAIError.apiError(errorMessage)))
                    return
                }
            }
            
            do {
                let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                
                if let error = response.error {
                    print("API Error: \(error.message)")
                    completion(.failure(OpenAIError.apiError(error.message)))
                    return
                }
                
                if let content = response.choices.first?.message.content {
                    print("Successfully received response from OpenAI")
                    completion(.success(content))
                } else {
                    print("No content in response")
                    completion(.failure(OpenAIError.apiError("No content in response")))
                }
            } catch {
                print("Decoding error: \(error)")
                
                // Print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                
                completion(.failure(OpenAIError.decodingError))
            }
        }.resume()
    }
} 