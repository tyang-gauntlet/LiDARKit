import Foundation
import Security

// MARK: - ConfigError
enum ConfigError: Error {
    case apiKeyNotFound
    case invalidAPIKey
    case keychainError(OSStatus)
}

// MARK: - APIKeyManager
class APIKeyManager {
    static let debugLogging = true
    
    static func logKeychainStatus(_ status: OSStatus, operation: String) {
        if debugLogging {
            let message: String
            switch status {
            case errSecSuccess:
                message = "Success"
            case errSecDuplicateItem:
                message = "Duplicate Item"
            case errSecItemNotFound:
                message = "Item Not Found"
            case errSecAuthFailed:
                message = "Authorization Failed"
            case errSecDecode:
                message = "Decode Error"
            case errSecNotAvailable:
                message = "Not Available"
            default:
                message = "Unknown Error (\(status))"
            }
            print("Keychain \(operation) Status: \(message)")
        }
    }
    
    static func saveAPIKey(_ apiKey: String) throws {
        print("Attempting to save API key to Keychain...")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAIAPIKey",
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        logKeychainStatus(status, operation: "Save")
        
        if status == errSecDuplicateItem {
            print("API key already exists in Keychain, updating...")
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "OpenAIAPIKey"
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: apiKey.data(using: .utf8)!
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            logKeychainStatus(updateStatus, operation: "Update")
            if updateStatus != errSecSuccess {
                throw ConfigError.keychainError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw ConfigError.keychainError(status)
        }
        print("API key successfully saved to Keychain")
    }
    
    static func getAPIKey() -> String? {
        print("Attempting to retrieve API key from Keychain...")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAIAPIKey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        logKeychainStatus(status, operation: "Retrieve")
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            print("Successfully retrieved API key from Keychain")
            return key
        }
        print("Failed to retrieve API key from Keychain")
        return nil
    }
    
    static func deleteAPIKey() throws {
        print("Attempting to delete API key from Keychain...")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAIAPIKey"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        logKeychainStatus(status, operation: "Delete")
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw ConfigError.keychainError(status)
        }
        print("API key successfully deleted from Keychain")
    }
}

// MARK: - Config
struct Config {
    // API Keys
    static let openAIAPIKey: String = {
        print("\n=== Starting API Key Loading Process ===")
        
        // Delete any existing API key from Keychain
        print("Deleting any existing API key from Keychain...")
        do {
            try APIKeyManager.deleteAPIKey()
            print("Successfully deleted existing API key from Keychain")
        } catch {
            print("Error deleting API key from Keychain: \(error)")
        }
        
        // Try to load from plist and store in Keychain
        print("Attempting to load API key from plist...")
        if let key = loadAPIKeyFromPlist() {
            print("Found valid API key in plist, saving to Keychain...")
            do {
                try APIKeyManager.saveAPIKey(key)
                print("Successfully saved API key to Keychain")
            } catch {
                print("Failed to save API key to Keychain: \(error)")
            }
            return key
        }
        
        print("No valid API key found in any location")
        return ""
    }()
    
    private static func loadAPIKeyFromPlist() -> String? {
        #if DEBUG
        print("Debug build: Attempting to load API key from plist...")
        
        // Print bundle information for debugging
        print("Bundle main path: \(Bundle.main.bundlePath)")
        if let resourcePath = Bundle.main.resourcePath {
            print("Resource path: \(resourcePath)")
        }
        
        // Try different plist files in order of preference
        let plistNames = ["ApiKeys", "LiDARKitAIKeys", "TestKeys"]
        
        for plistName in plistNames {
            print("\nTrying to load \(plistName).plist...")
            
            // Try to load the plist using Bundle.main.path
            if let plistPath = Bundle.main.path(forResource: plistName, ofType: "plist") {
                print("Found \(plistName).plist at path: \(plistPath)")
                if let plistDict = NSDictionary(contentsOfFile: plistPath),
                   let apiKey = plistDict["OpenAIAPIKey"] as? String {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedKey.isEmpty && trimmedKey.hasPrefix("sk-") {
                        print("Successfully loaded valid API key from \(plistName).plist")
                        return trimmedKey
                    } else {
                        print("Found API key in \(plistName).plist but it's invalid (empty or wrong format)")
                    }
                } else {
                    print("Failed to load plist or find OpenAIAPIKey in \(plistName).plist")
                }
            } else {
                print("Could not find \(plistName).plist in bundle")
            }
            
            // Try with Resources directory
            if let plistPath = Bundle.main.path(forResource: "Resources/\(plistName)", ofType: "plist") {
                print("Found \(plistName).plist at path with Resources prefix: \(plistPath)")
                if let plistDict = NSDictionary(contentsOfFile: plistPath),
                   let apiKey = plistDict["OpenAIAPIKey"] as? String {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedKey.isEmpty && trimmedKey.hasPrefix("sk-") {
                        print("Successfully loaded valid API key from Resources/\(plistName).plist")
                        return trimmedKey
                    } else {
                        print("Found API key in Resources/\(plistName) but it's invalid (empty or wrong format)")
                    }
                } else {
                    print("Failed to load plist or find OpenAIAPIKey in Resources/\(plistName)")
                }
            } else {
                print("Could not find Resources/\(plistName).plist in bundle")
            }
        }
        
        // Debug: List all files in bundle
        print("\nListing all bundle contents for debugging:")
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("Found \(files.count) files in bundle at \(resourcePath):")
                for file in files {
                    print("- \(file)")
                    if file.hasSuffix(".plist") {
                        print("  Checking contents of \(file)...")
                        let fullPath = "\(resourcePath)/\(file)"
                        if let plist = NSDictionary(contentsOfFile: fullPath) {
                            print("  Keys in \(file): \(plist.allKeys)")
                        } else {
                            print("  Failed to read \(file) as a plist")
                        }
                    }
                    
                    // Check if there's a Resources directory
                    if file == "Resources" {
                        print("  Found Resources directory, checking contents...")
                        let resourcesPath = "\(resourcePath)/\(file)"
                        do {
                            let resourceFiles = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                            print("  Found \(resourceFiles.count) files in Resources directory:")
                            for resourceFile in resourceFiles {
                                print("  - \(resourceFile)")
                                if resourceFile.hasSuffix(".plist") {
                                    print("    Checking contents of Resources/\(resourceFile)...")
                                    let fullPath = "\(resourcesPath)/\(resourceFile)"
                                    if let plist = NSDictionary(contentsOfFile: fullPath) {
                                        print("    Keys in Resources/\(resourceFile): \(plist.allKeys)")
                                        if let apiKey = plist["OpenAIAPIKey"] as? String {
                                            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmedKey.isEmpty && trimmedKey.hasPrefix("sk-") {
                                                print("    Found valid API key in Resources/\(resourceFile)")
                                                return trimmedKey
                                            }
                                        }
                                    } else {
                                        print("    Failed to read Resources/\(resourceFile) as a plist")
                                    }
                                }
                            }
                        } catch {
                            print("  Error listing Resources directory contents: \(error)")
                        }
                    }
                }
            } catch {
                print("Error listing bundle contents: \(error)")
            }
        }
        #else
        print("Release build: Skipping plist load")
        #endif
        return nil
    }
    
    // API Endpoints
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // App Settings
    static let defaultModelName = "gpt-4o-mini"  // Using a widely available model
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