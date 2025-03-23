import Foundation
import Combine
import OSLog

class OpenAIManager: ObservableObject {
    private let keychainService = "com.quickevent.openai"
    private let logger = Logger(subsystem: "com.quickevent", category: "OpenAI")
    
    @Published var apiKey: String = ""
    @Published var isApiKeySet: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var lastResponse: String?
    
    init() {
        loadApiKey()
    }
    
    private func loadApiKey() {
        do {
            if let key = try KeychainManager.shared.retrieveApiKey(service: keychainService) {
                self.apiKey = key
                self.isApiKeySet = true
                self.errorMessage = nil
            } else {
                self.isApiKeySet = false
            }
        } catch {
            self.errorMessage = "Failed to load API key: \(error.localizedDescription)"
            self.isApiKeySet = false
        }
    }
    
    func saveApiKey(_ key: String) {
        do {
            try KeychainManager.shared.saveApiKey(key, service: keychainService)
            self.apiKey = key
            self.isApiKeySet = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
    }
    
    func clearApiKey() {
        do {
            try KeychainManager.shared.deleteApiKey(service: keychainService)
            self.apiKey = ""
            self.isApiKeySet = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to clear API key: \(error.localizedDescription)"
        }
    }
    
    // Validate that the key roughly looks like an OpenAI API key
    func validateApiKey(_ key: String) -> Bool {
        // Most OpenAI keys start with "sk-" and are followed by alphanumeric characters
        let pattern = "^sk-[a-zA-Z0-9]{32,}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }
    
    // Send a message to OpenAI and get a response
    func sendMessage(_ message: String) async -> String {
        guard isApiKeySet else {
            let error = "API key not configured. Please set up your OpenAI API key in settings."
            logger.error("\(error)")
            return error
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        let endpoint = "https://api.openai.com/v1/chat/completions"
        let model = "gpt-3.5-turbo" // Using 3.5-turbo as it's more cost-effective
        
        // Log the request
        logger.info("Sending request to OpenAI: \(message)")
        // Create the request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": message]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            let error = "Error: Cannot create JSON data"
            logger.error("\(error)")
            await MainActor.run {
                isLoading = false
            }
            return error
        }
        
        guard let url = URL(string: endpoint) else {
            let error = "Error: Invalid URL"
            logger.error("\(error)")
            await MainActor.run {
                isLoading = false
            }
            return error
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 30 // 30 second timeout
        
        // Create a custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 30
        config.timeoutIntervalForRequest = 30
        
        // Create a custom URLSession
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            await MainActor.run {
                isLoading = false
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = "Error: Invalid response from server"
                logger.error("\(error)")
                return error
            }
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                let error = "API Error (\(httpResponse.statusCode)): \(responseString)"
                logger.error("\(error)")
                return error
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    // Log the full response for debugging
                    logger.info("OpenAI Response JSON: \(String(describing: jsonResponse))")
                    
                    // Log the content we're using
                    logger.info("OpenAI Response Content: \(content)")
                    
                    // Update the last response
                    await MainActor.run {
                        self.lastResponse = content
                    }
                    
                    // Also print to standard console for Xcode console visibility
                    print("📝 OpenAI Response: \(content)")
                    
                    return content
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown format"
                    let error = "Error parsing response: \(responseString)"
                    logger.error("\(error)")
                    return error
                }
            } catch {
                let parseError = "JSON parsing error: \(error.localizedDescription)"
                logger.error("\(parseError)")
                return parseError
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            
            logger.error("Network error: \(error.localizedDescription)")
            
            // Check for specific network errors
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return "Not connected to the internet. Please check your connection."
                case NSURLErrorTimedOut:
                    return "Request timed out. Please try again."
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                    return "Cannot connect to OpenAI servers. Check your internet connection or try again later."
                default:
                    return "Network error: \(error.localizedDescription)"
                }
            }
            
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    // Test API with a simple request
    func testAPI() async -> String {
        return await sendMessage("Hello, please provide a short response to test the API connection.")
    }
} 