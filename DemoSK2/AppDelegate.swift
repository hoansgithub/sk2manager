//
//  AppDelegate.swift
//  DemoSK2
//
//  Created by HoanNL on 23/08/2023.
//

import UIKit
class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        Task {
            do {
                try await StoreManager.shared.startService(productIdentifiers: AppProductType.allCases.map({$0.rawValue}))
            }
            catch {
                debugPrint(error)
            }
        }
        return true
    }
    
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
            sceneConfig.delegateClass = Self.self
        return sceneConfig
    }
    
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        Task {
            await StoreManager.shared.updateCustomerProductStatus()
        }
    }
    
}
