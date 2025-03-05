import UIKit

class SettingsViewController: UIViewController {
    
    private let apiKeyTextField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let modelSelectionSegmentedControl = UISegmentedControl(items: ["GPT-3.5", "GPT-4"])
    private let maxTokensSlider = UISlider()
    private let maxTokensLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Settings"
        
        // API Key TextField
        apiKeyTextField.placeholder = "Enter OpenAI API Key"
        apiKeyTextField.borderStyle = .roundedRect
        apiKeyTextField.isSecureTextEntry = true
        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(apiKeyTextField)
        
        // Model Selection
        modelSelectionSegmentedControl.selectedSegmentIndex = 0
        modelSelectionSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modelSelectionSegmentedControl)
        
        // Max Tokens Slider
        maxTokensSlider.minimumValue = 100
        maxTokensSlider.maximumValue = 4000
        maxTokensSlider.value = Float(Config.maxTokens)
        maxTokensSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        maxTokensSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(maxTokensSlider)
        
        // Max Tokens Label
        maxTokensLabel.text = "Max Tokens: \(Config.maxTokens)"
        maxTokensLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(maxTokensLabel)
        
        // Save Button
        saveButton.setTitle("Save Settings", for: .normal)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            apiKeyTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            apiKeyTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiKeyTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            modelSelectionSegmentedControl.topAnchor.constraint(equalTo: apiKeyTextField.bottomAnchor, constant: 20),
            modelSelectionSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modelSelectionSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            maxTokensLabel.topAnchor.constraint(equalTo: modelSelectionSegmentedControl.bottomAnchor, constant: 20),
            maxTokensLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            maxTokensLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            maxTokensSlider.topAnchor.constraint(equalTo: maxTokensLabel.bottomAnchor, constant: 10),
            maxTokensSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            maxTokensSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            saveButton.topAnchor.constraint(equalTo: maxTokensSlider.bottomAnchor, constant: 30),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func loadSettings() {
        // Try to load API key from keychain
        do {
            let apiKeyData = try KeychainManager.get(service: "LiDARKitAI", account: "openai_api_key")
            if let apiKey = String(data: apiKeyData, encoding: .utf8) {
                apiKeyTextField.text = apiKey
            }
        } catch {
            print("Could not load API key: \(error)")
            // Try to load from ApiKeys.plist as fallback
            if !Config.openAIAPIKey.isEmpty {
                apiKeyTextField.text = Config.openAIAPIKey
            }
        }
        
        // Set model selection
        if Config.defaultModelName == "gpt-4" {
            modelSelectionSegmentedControl.selectedSegmentIndex = 1
        } else {
            modelSelectionSegmentedControl.selectedSegmentIndex = 0
        }
        
        // Set max tokens
        maxTokensSlider.value = Float(Config.maxTokens)
        maxTokensLabel.text = "Max Tokens: \(Config.maxTokens)"
    }
    
    @objc private func sliderValueChanged() {
        let value = Int(maxTokensSlider.value)
        maxTokensLabel.text = "Max Tokens: \(value)"
    }
    
    @objc private func saveButtonTapped() {
        var savedSuccessfully = false
        var errorMessage = ""
        
        // Save API key to keychain
        if let apiKey = apiKeyTextField.text, !apiKey.isEmpty {
            do {
                let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                try KeychainManager.save(
                    service: "LiDARKitAI",
                    account: "openai_api_key",
                    password: trimmedKey.data(using: .utf8) ?? Data()
                )
                savedSuccessfully = true
                
                // Force reload of Config.openAIAPIKey by accessing it
                let _ = Config.openAIAPIKey
                Config.logConfiguration()
            } catch {
                print("Could not save API key: \(error)")
                errorMessage = "Failed to save API key: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "API key cannot be empty"
        }
        
        // Show appropriate alert
        if savedSuccessfully {
            let alert = UIAlertController(
                title: "Settings Saved",
                message: "Your API key has been saved successfully. Length: \(apiKeyTextField.text?.count ?? 0) characters",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(
                title: "Error",
                message: errorMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
} 