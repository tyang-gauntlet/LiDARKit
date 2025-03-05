import Foundation

struct Config {
    // Fallback API key in case the plist file isn't loaded
    private static let fallbackAPIKey = "" // API key should be loaded from ApiKeys.plist only
    
    // API Keys
    static let openAIAPIKey: String = {
        // Get API key directly from ApiKeys.plist
        print("Attempting to load API key from ApiKeys.plist...")
        
        // Check if the file exists in the main bundle
        let bundle = Bundle.main
        print("Bundle path: \(bundle.bundlePath)")
        
        // List all resources in the bundle to check if ApiKeys.plist is included
        if let resourcePaths = bundle.paths(forResourcesOfType: "plist", inDirectory: nil) as? [String] {
            print("Found \(resourcePaths.count) plist files in bundle:")
            for path in resourcePaths {
                print("  - \(path)")
            }
        }
        
        guard let path = bundle.path(forResource: "ApiKeys", ofType: "plist") else {
            print("Error: ApiKeys.plist file not found in the bundle")
            
            // Try to find the file in the filesystem
            let fileManager = FileManager.default
            let currentDirectory = fileManager.currentDirectoryPath
            print("Current directory: \(currentDirectory)")
            
            // Check if the file exists in the project directory
            let projectPath = "\(currentDirectory)/LiDARKitAI/ApiKeys.plist"
            if fileManager.fileExists(atPath: projectPath) {
                print("ApiKeys.plist found at: \(projectPath)")
                
                // Try to load it directly
                if let plist = NSDictionary(contentsOfFile: projectPath),
                   let apiKey = plist["OpenAIAPIKey"] as? String {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Successfully loaded API key from filesystem path")
                    return trimmedKey
                }
            } else {
                print("ApiKeys.plist not found at: \(projectPath)")
            }
            
            // Check if the file exists in the parent directory
            let parentPath = "\(currentDirectory)/ApiKeys.plist"
            if fileManager.fileExists(atPath: parentPath) {
                print("ApiKeys.plist found at: \(parentPath)")
                
                // Try to load it directly
                if let plist = NSDictionary(contentsOfFile: parentPath),
                   let apiKey = plist["OpenAIAPIKey"] as? String {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Successfully loaded API key from parent directory")
                    return trimmedKey
                }
            } else {
                print("ApiKeys.plist not found at: \(parentPath)")
            }
            
            print("No API key found in any location")
            return fallbackAPIKey
        }
        
        print("ApiKeys.plist path: \(path)")
        
        guard let plist = NSDictionary(contentsOfFile: path) else {
            print("Error: Failed to load ApiKeys.plist as a dictionary")
            return fallbackAPIKey
        }
        
        print("ApiKeys.plist loaded successfully with \(plist.count) keys")
        
        guard let apiKey = plist["OpenAIAPIKey"] as? String else {
            print("Error: OpenAIAPIKey not found in ApiKeys.plist or is not a string")
            return fallbackAPIKey
        }
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            print("Warning: OpenAIAPIKey is empty in ApiKeys.plist")
            return fallbackAPIKey
        }
        
        print("Successfully loaded OpenAI API key from ApiKeys.plist")
        print("API key length: \(trimmedKey.count) characters")
        return trimmedKey
    }()
    
    // API Endpoints
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // App Settings
    static let defaultModelName = "gpt-3.5-turbo"  // Using a widely available model
    static let maxTokens = 500
    
    // Feature Flags
    static let enableDebugLogging = true
    static let enableAdvancedFeatures = false
    
    // Log configuration on app start
    static func logConfiguration() {
        if enableDebugLogging {
            print("=== App Configuration ===")
            print("OpenAI API Key: \(openAIAPIKey.isEmpty ? "Not set" : "Set (hidden)")")
            print("OpenAI API Key Length: \(openAIAPIKey.count) characters")
            print("OpenAI Endpoint: \(openAIEndpoint)")
            print("Model: \(defaultModelName)")
            print("Max Tokens: \(maxTokens)")
            print("========================")
        }
    }
} 