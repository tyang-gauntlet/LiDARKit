import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("SceneDelegate: scene(_:willConnectTo:options:) called")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            print("SceneDelegate: Failed to cast scene to UIWindowScene")
            return
        }
        print("SceneDelegate: Successfully got windowScene")
        
        window = UIWindow(windowScene: windowScene)
        window?.backgroundColor = .systemBackground
        print("SceneDelegate: Created window with system background color")
        
        let rootVC = CaptureViewController()
        window?.rootViewController = rootVC
        print("SceneDelegate: Set CaptureViewController as root")
        
        window?.makeKeyAndVisible()
        print("SceneDelegate: Made window key and visible")
        
        if let window = window {
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 320, height: 480)
            window.frame = windowScene.coordinateSpace.bounds
            print("SceneDelegate: Set window frame to \(window.frame)")
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("SceneDelegate: sceneDidDisconnect called")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("SceneDelegate: sceneDidBecomeActive called")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("SceneDelegate: sceneWillResignActive called")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("SceneDelegate: sceneWillEnterForeground called")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("SceneDelegate: sceneDidEnterBackground called")
    }
} 