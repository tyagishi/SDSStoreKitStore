//
// note: basic idea comes from Apple's example
//

import Foundation
import os
import StoreKit

public typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
    case unknownProduct
    case duplicatePurchase
}

public class StoreKitStore: ObservableObject {
    public let logger = Logger(subsystem: "com.smalldesksoftware.StoreKitStore", category: "StoreKitStore")
    public let allProductIDs: Set<String>
    @Published public private(set) var allProducts: [Product] = []
    @Published public private(set) var purchasedIdentifiers = Set<String>()

    var updateListenerTask: Task<Void, Error>? = nil

    public init(productIDs: [String]) {
        self.allProductIDs = Set(productIDs)

        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            //Initialize the store by starting a product request.
            await requestProducts()
            await retrievePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver content to the user.
                    await self.updatePurchasedIdentifiers(transaction)

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a receipt it can read but it failed verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }

    @MainActor
    public func requestProducts() async {
        do {
            //Request products from the App Store using the identifiers
            let storeProducts = try await Product.products(for: allProductIDs)

            allProducts = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed product request: \(error)")
        }
    }
    
    @MainActor
    public func addPurchasedProduct(_ productID: String) async {
        guard !purchasedIdentifiers.contains(productID) else {
            logger.error("try to buy purchased product \(productID)")
            return
        }
        self.purchasedIdentifiers.insert(productID)
    }
    
    public func purchase(_ productID: String) async throws -> Transaction? {
        guard let product = allProducts.first(where: { $0.id == productID }) else { throw StoreError.unknownProduct }
        guard !purchasedIdentifiers.contains(productID) else { throw StoreError.duplicatePurchase }
        //Begin a purchase.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            //Deliver content to the user.
            await updatePurchasedIdentifiers(transaction)

            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    public func isPurchased(_ productIdentifier: String) async throws -> Bool {
        //Get the most recent transaction receipt for this `productIdentifier`.
        guard let result = await Transaction.latest(for: productIdentifier) else {
            //If there is no latest transaction, the product has not been purchased.
            return false
        }

        let transaction = try checkVerified(result)

        //Ignore revoked transactions, they're no longer purchased.

        //For subscriptions, a user can upgrade in the middle of their subscription period. The lower service
        //tier will then have the `isUpgraded` flag set and there will be a new transaction for the higher service
        //tier. Ignore the lower service tier transactions which have been upgraded.
        return transaction.revocationDate == nil && !transaction.isUpgraded
    }

    public func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check if the transaction passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
            throw StoreError.failedVerification
        case .verified(let safe):
            //If the transaction is verified, unwrap and return it.
            return safe
        }
    }

    @MainActor
    public func retrievePurchasedProducts() async {
        var purchased: Set<String> = []

        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            //Don't operate on this transaction if it's not verified.
            if case .verified(let transaction) = result {
                if allProductIDs.contains(transaction.productID),
                   transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }
        purchasedIdentifiers = purchased
    }
    
    
    @MainActor
    public func updatePurchasedIdentifiers(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            //If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
            purchasedIdentifiers.insert(transaction.productID)
//        } else {
//            if transaction.productID != StoreKitStore.trialID {
//                //If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
//                purchasedIdentifiers.remove(transaction.productID)
//            } // keep trialID as purchased even after refunded
        }
    }
}
