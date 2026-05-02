# SDSStoreKitStore

boiler plate for StoreKit

## HowToUse
Step1: initialize SDSStoreKit with passing LicenseHander for your product handling 

Note: probably defining product info with String type should make things easier,
since productID comes from app store is String.

Followings are example code.
first public static let defines product IDs
other functions for api for app-internal use.

for modularity, those are under extension, but that is just for modularity/convenience.

in somewhere
```
class MyHandler: LicenseHander {
    func unverifiedResult(_ result: VerificationResult<StoreKit.Transaction>) { }  called when unknown transaction can not be verified
    func validateLicense(_ productID: String) {} // called when license is validated
    func revokeLicense(_ productID: String,_ revokeDate: Date) {}  // called when license is revoked
    func expireLicense(_ expireDate: Date) {} // called when license is expired (via family share)
}

struct SomeView: View (or App) {
    @State private var storeKit: SDSStoreKit
    init() {
        self._storeKit = State(wrappedValue: SDSStoreKit(MyHandler())) // maybe MyHandler will be instanciated somewhere else
    }
    var body: ...

```
