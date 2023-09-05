//
//  DemoSK2App.swift
//  DemoSK2
//
//  Created by HoanNL on 21/08/2023.
//

import SwiftUI

@main
struct DemoSK2App: App {
    @StateObject var vm = ViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(vm)
        }
    }
}
