# SDSStoreKitStore

boiler plate for StoreKit

## HowToUse
Step1: define all product IDs
Step2: pass those for StoreKitStore initializer
Step3: define license check function (for your use cases)

Followings are example code.
first public static let defines product IDs
other functions for api for app-internal use.

for modularity, those are under extension, but that is just for modularity/convenience.


```
extension StoreKitStore {
    public static let trialID = "com.smalldesksoftware.pomodoro.trial"
    public static let proID = "com.smalldesksoftware.pomodoro.pro"
    public static let allIDs = [StoreKitStore.trialID, StoreKitStore.proID]
    static let trialDuration: TimeInterval = 60 * 60 * 24 * 7 // 7 days
    
    func imageNameForProduct(_ productID: String) -> String {
        let imageNames: [String: String] = [StoreKitStore.trialID: "StoreItemFreeTrial",
                                           StoreKitStore.proID: "StoreItemPro"]
        return imageNames[productID, default: "StoreItemFreeTrial"]
    }
    
    func hasLicenseForCalendar(_ now: Date) async -> Bool {
        if self.purchasedIdentifiers.contains(StoreKitStore.proID) { return true }
        do {
            let trial = try await isTrialInDuration(now)
            return trial
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        return false
    }

    func isTrialInDuration(_ now: Date) async throws -> Bool {
        //Get the most recent transaction receipt for this `productIdentifier`.
        guard let result = await Transaction.latest(for: StoreKitStore.trialID) else {
            //If there is no latest transaction, the product has not been purchased.
            return false
        }

        let transaction = try checkVerified(result)
        if (now.timeIntervalSinceReferenceDate - transaction.originalPurchaseDate.timeIntervalSinceReferenceDate) < StoreKitStore.trialDuration {
            return true
        }
        return false
    }
}
```
