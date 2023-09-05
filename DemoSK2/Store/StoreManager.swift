//
//  StoreManager.swift
//  DemoSK2
//
//  Created by HoanNL on 23/08/2023.
//

import Foundation
import StoreKit


public enum StoreError: Error {
    case failedVerification
}

final class StoreManager: @unchecked Sendable {
    
    typealias Transaction = StoreKit.Transaction
    typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
    typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState
    typealias TransactionState = (result: Product.PurchaseResult,transaction: Transaction?)
    
    @Published private(set) var nonConsumables: [Product] = []
    @Published private(set) var consumables: [Product] = []
    @Published private(set) var autoRenewables: [Product] = []
    @Published private(set) var nonRenewables: [Product] = []
    
    @Published private(set) var purchasedNonConsumables: [Product] = []
    @Published private(set) var purchasedAutoRenewables: [Product] = []
    @Published private(set) var purchasedNonRenewables: [Product] = []
    
    
    @Published private(set) var subscriptionGroupStatus: [String: RenewalState] = [:]
    
    var updateListenerTask: Task<Void, Error>? = nil
    
    static let shared = StoreManager()
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func startService(productIdentifiers: [String]) async throws {
        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()
        try await requestProducts(identifiers:productIdentifiers)
        await updateCustomerProductStatus()
    }
    
    func requestProducts(identifiers: [String]) async throws {
        let products = try await Product.products(for: identifiers)
        var nonConsumables: [Product] = []
        var newRenewables: [Product] = []
        var newNonRenewables: [Product] = []
        var consumables: [Product] = []
        
        //Filter the products into categories based on their type.
        for product in products {
            switch product.type {
            case .consumable:
                consumables.append(product)
            case .nonConsumable:
                nonConsumables.append(product)
            case .autoRenewable:
                newRenewables.append(product)
            case .nonRenewable:
                newNonRenewables.append(product)
            default:
                //Ignore this product.
                print("Unknown product")
            }
        }
        
        //Sort each product category by price, lowest to highest, to update the store.
        self.consumables = consumables
        self.nonConsumables = nonConsumables
        self.autoRenewables = newRenewables
        self.nonRenewables = newNonRenewables
    }
    
    func purchase(_ product: Product) async throws -> TransactionState {
        //Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try StoreManager.checkVerified(verification)
            
            //Always finish a transaction.
            await transaction.finish()
            
            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()
            return (result,transaction)
        default:
            return (result, nil)
        }
    }
    
    func updateCustomerProductStatus() async {
        var newNonConsumables: [Product] = []
        var newAutoRenewables: [Product] = []
        var newNonRenewables: [Product] = []
        var newSubscriptionGroupStatus: [String: RenewalState] = [:]
        
        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try StoreManager.checkVerified(result)
                debugPrint(transaction.productID)
                debugPrint(transaction.purchaseDate)
                debugPrint(transaction.isUpgraded)
                debugPrint(transaction.ownershipType)
                debugPrint(transaction.expirationDate)
                debugPrint(transaction.revocationDate)
                debugPrint(transaction.purchasedQuantity)
                debugPrint(transaction.purchaseDate)
                debugPrint(transaction.originalPurchaseDate)
                
                if transaction.purchaseDate != transaction.originalPurchaseDate {
                    debugPrint("RENEW")
                }
                
                //Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .nonConsumable:
                    if let nonConsumable = nonConsumables.first(where: { $0.id == transaction.productID }) {
                        newNonConsumables.append(nonConsumable)
                    }
                case .nonRenewable:
                    if let nonRenewable = nonRenewables.first(where: { $0.id == transaction.productID }) {
                        newNonRenewables.append(nonRenewable)
                    }
                case .autoRenewable:
                    if let subscription = autoRenewables.first(where: { $0.id == transaction.productID }) {
                        newAutoRenewables.append(subscription)
                    }
                default:
                    break
                }
            } catch {
                print(error)
            }
        }

        //Update the store information with the purchased products.
        self.purchasedNonConsumables = newNonConsumables
        self.purchasedNonRenewables = newNonRenewables

        //Update the store information with auto-renewable subscription products.
        self.purchasedAutoRenewables = newAutoRenewables

        //Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
        //is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
        //group, so products in the subscriptions array all belong to the same group. The statuses that
        //`product.subscription.status` returns apply to the entire subscription group.
        
        for prod in newAutoRenewables {
            guard let groupID = prod.subscription?.subscriptionGroupID,
                  let status = try? await prod.subscription?.status.first?.state else { return }
            newSubscriptionGroupStatus[groupID] = status
        }
        self.subscriptionGroupStatus = newSubscriptionGroupStatus
    }
    
    func restore() async throws {
        try await AppStore.sync()
    }
}

private extension StoreManager {
    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try StoreManager.checkVerified(result)
                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
}
