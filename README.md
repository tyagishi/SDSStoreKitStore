# SDSStoreKitStore

boiler plate for StoreKit

## HowToUse
Step1: initialize SDSStoreKit with passing LicenseHander for your product handling 

Note: probably defining product info with String type should make things easier,
since productID comes from app store is String.

```
class MyHandler: LicenseHander {
    // called when unknown transaction can not be verified
    func unverifiedResult(_ result: VerificationResult<StoreKit.Transaction>) { }

    // called when license is validated
    func validateLicense(_ productID: String) {} 

    // called when license is revoked
    func revokeLicense(_ productID: String,_ revokeDate: Date) {}

    // called when license is expired (via family share)
    func expireLicense(_ productID: String,_ expireDate: Date) {}
}

struct SomeView: View (or App) {
    @State private var storeKit: SDSStoreKit
    init() {
        self._storeKit = State(wrappedValue: SDSStoreKit(MyHandler())) // maybe MyHandler will be instanciated somewhere else
    }
    var body: ...

```
