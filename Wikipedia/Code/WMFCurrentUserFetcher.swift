public enum WMFCurrentlyLoggedInUserFetcherError: LocalizedError {
    case cannotExtractUserInfo
    case blankUsernameOrPassword
    public var errorDescription: String? {
        switch self {
        case .cannotExtractUserInfo:
            return "Could not extract user info"
        case .blankUsernameOrPassword:
            return "Blank username or password"
        }
    }
}

@objc public class WMFCurrentUser: NSObject {
    @objc public let userID: Int
    @objc public let name: String
    @objc public let groups: [String]
    @objc public let editCount: UInt64
    @objc public let isBlocked: Bool
    @objc public let isIP: Bool
    @objc public let isTemp: Bool
    @objc public let registrationDateString: String?
    init(userID: Int, name: String, groups: [String], editCount: UInt64, isBlocked: Bool, isIP: Bool, isTemp: Bool, registrationDateString: String?) {
        assert(!(isTemp && isIP), "Invalid values. A user cannot both be IP and Temp.")
        self.userID = userID
        self.name = name
        self.groups = groups
        self.editCount = editCount
        self.isBlocked = isBlocked
        self.isIP = isIP
        self.isTemp = isTemp
        self.registrationDateString = registrationDateString
    }
}

public class WMFCurrentUserFetcher: Fetcher {
    public func fetch(siteURL: URL, success: @escaping (WMFCurrentUser) -> Void, failure: @escaping WMFErrorHandler) {
        let parameters = [
            "action": "query",
            "meta": "userinfo",
            "uiprop": "groups|blockinfo|editcount|registrationdate",
            "format": "json"
        ]
        
        performMediaWikiAPIPOST(for: siteURL, with: parameters) { (result, response, error) in
            if let error = error {
                failure(error)
                return
            }
            guard
                let query = result?["query"] as? [String : Any],
                let userinfo = query["userinfo"] as? [String : Any],
                let userID = userinfo["id"] as? Int,
                let userName = userinfo["name"] as? String
                else {
                    failure(WMFCurrentlyLoggedInUserFetcherError.cannotExtractUserInfo)
                    return
            }
            
            let isIP = userinfo["anon"] != nil
            let isTemp = userinfo["temp"] != nil
            
            let editCount = userinfo["editcount"] as? UInt64 ?? 0
            let registrationDateString = userinfo["registrationdate"] as? String
            
            var isBlocked = false
            if userinfo["blockid"] is UInt64 {
                let blockPartial = (userinfo["blockpartial"] as? Bool ?? false)
                if !blockPartial {
                    isBlocked = true
                }
            }
            
            let groups = userinfo["groups"] as? [String] ?? []
            success(WMFCurrentUser.init(userID: userID, name: userName, groups: groups, editCount: editCount, isBlocked: isBlocked, isIP: isIP, isTemp: isTemp, registrationDateString: registrationDateString))
        }
    }
}
