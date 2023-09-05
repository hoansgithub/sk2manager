//
//  ViewModel.swift
//  DemoSK2
//
//  Created by HoanNL on 21/08/2023.
//

import Foundation
import StoreKit
import Combine
class ViewModel: ObservableObject {
    @Published private(set) var nonConsumables: [Product] = []
    @Published private(set) var consumables: [Product] = []
    @Published private(set) var autoRenewables: [Product] = []
    @Published private(set) var nonRenewables: [Product] = []
    @Published private(set) var publishedConsumableTransactionIDs: [UInt64] = []
    
    
    @Published private(set) var purchasedNonConsumables: [Product] = []
    @Published private(set) var purchasedAutoRenewables: [Product] = []
    @Published private(set) var purchasedNonRenewables: [Product] = []
    
    @UserDefaultsPublisher(wrappedValue: [UInt64](), key: "ViewModel.consumableTransactionIDs") private var consumableTransactionIDs: [UInt64]
    
    var cancellables = Set<AnyCancellable>()
    init() {
        StoreManager.shared
            .$nonConsumables
            .receive(on: RunLoop.main)
            .assign(to: \.nonConsumables, on: self)
            .store(in: &cancellables)
        StoreManager.shared
            .$consumables.receive(on: RunLoop.main)
            .assign(to: \.consumables, on: self).store(in: &cancellables)
        StoreManager.shared
            .$autoRenewables.receive(on: RunLoop.main)
            .assign(to: \.autoRenewables, on: self).store(in: &cancellables)
        StoreManager.shared
            .$nonRenewables.receive(on: RunLoop.main)
            .assign(to: \.nonRenewables, on: self).store(in: &cancellables)
        
        $consumableTransactionIDs.receive(on: RunLoop.main).assign(to: \.publishedConsumableTransactionIDs, on: self).store(in: &cancellables)
        
        
        //purchased products binders
        StoreManager.shared
            .$purchasedNonConsumables.receive(on: RunLoop.main)
            .assign(to: \.purchasedNonConsumables, on: self).store(in: &cancellables)
        StoreManager.shared
            .$purchasedAutoRenewables.receive(on: RunLoop.main)
            .assign(to: \.purchasedAutoRenewables, on: self).store(in: &cancellables)
        StoreManager.shared
            .$purchasedNonRenewables.receive(on: RunLoop.main)
            .assign(to: \.purchasedNonRenewables, on: self).store(in: &cancellables)
    }
    
    func purchase(_ product: Product) async throws {
        let state = try await StoreManager.shared.purchase(product)
        if let transaction = state.transaction, transaction.productType == .consumable {
            consumableTransactionIDs.append(transaction.originalID)
        }
    }
    
    func getProducts(section: Product.ProductType) -> [Product] {
        switch section {
        case .autoRenewable: return autoRenewables
        case .consumable: return consumables
        case .nonConsumable: return nonConsumables
        case .nonRenewable: return nonRenewables
        default:
            return []
        }
    }
}

@propertyWrapper
public class UserDefaultsPublisher<Value> {
    let key: String
    private var defaultValue: Value
    private lazy var subject = CurrentValueSubject<Value, Never>(wrappedValue)
    private var userDefaults = UserDefaults.standard
    
    
    
    public var projectedValue: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public var wrappedValue: Value {
        get {
            let storedValue = userDefaults.value(forKey: key) as? Value ?? defaultValue
            return storedValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
            subject.value = newValue
        }
    }
    
    public init(wrappedValue defaultValue: Value, key: String) {
        self.key = key
        self.defaultValue = defaultValue
    }

}
