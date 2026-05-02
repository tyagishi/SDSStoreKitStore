//
//  File.swift
//  SDSStoreKitStore
//
//  Created by Tomoaki Yagishita on 2026/05/02.
//

import Foundation
import StoreKit

public protocol LicenseHander {
    func unverifiedResult(_ result: VerificationResult<StoreKit.Transaction>)
    func validateLicense(_ productID: String)
    func revokeLicense(_ productID: String,_ revokeDate: Date)
    func expireLicense(_ expireDate: Date) // revoke because of family share
}

@MainActor
@Observable
public final class SDSStoreKit {
    let licenseHandler: any LicenseHander
    
    public init(_ handler: any LicenseHander) {
        self.licenseHandler = handler
        // Because the tasks below capture 'self' in their closures, this object must be fully initialized before this point.
        Task(priority: .background) {
            // Finish any unfinished transactions -- for example, if the app was terminated before finishing a transaction.
            for await verificationResult in Transaction.unfinished {
                await handle(updatedTransaction: verificationResult)
            }

            // Fetch current entitlements for all product types except consumables.
            for await verificationResult in Transaction.currentEntitlements {
                await handle(updatedTransaction: verificationResult)
            }
        }
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                await handle(updatedTransaction: verificationResult)
            }
        }
    }
    
    private func handle(updatedTransaction verificationResult: VerificationResult<StoreKit.Transaction>) async {
        // The code below handles only verified transactions; handle unverified transactions based on your business model.
        guard case .verified(let transaction) = verificationResult else { licenseHandler.unverifiedResult(verificationResult); return }

        if let revokedDate = transaction.revocationDate {
            licenseHandler.revokeLicense(transaction.productID, revokedDate)
            await transaction.finish()
            return
        } else if let expirationDate = transaction.expirationDate {
            // In an app that supports Family Sharing, there might be another entitlement that still provides access to the subscription.
            licenseHandler.expireLicense(expirationDate)
            return
        } else {
            licenseHandler.validateLicense(transaction.productID)
            await transaction.finish()
            return
        }
    }
}
