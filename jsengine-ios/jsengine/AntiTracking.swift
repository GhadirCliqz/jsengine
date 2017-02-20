//
//  AntiTracking.swift
//  jsengine
//
//  Created by Ghadir Eraisha on 1/13/17.
//  Copyright © 2017 Cliqz GmbH. All rights reserved.
//

import Foundation

public class AntiTracking {
    
    //MARK: - Constants
    private static let moduleName = "antitracking"
    private static let enablePref = "antiTrackingTest"
    private static let qsBlockingPref = "attrackRemoveQueryStringTracking"
    private static let bloomFilterPref = "attrackBloomFilter"
    private static let forceBlockPref = "attrackForceBlock"
    
    //MARK: - Instant variables
    var engine: Engine
    var webReuest: WebRequest
    
    //MARK: - Init
    public init(engine: Engine) {
        self.engine = engine
        self.webReuest = engine.webRequest!
    }
    
    //MARK: - Public APIs
    public class func getDefaultPrefs(enabled: Bool? = true) -> [String: Bool] {
        var prefs: [String:Bool] = [String:Bool]()
        prefs[AntiTracking.enablePref] = enabled
        prefs[AntiTracking.bloomFilterPref] = true
        prefs[AntiTracking.qsBlockingPref] = true
        prefs[AntiTracking.forceBlockPref] = true
        
        return prefs
    }
    
    public func setEnabled(enabled: Bool) {
        dispatch_async(self.engine.dispatchQueue) { 
            self.engine.setPref(AntiTracking.bloomFilterPref, prefValue: true)
            self.engine.setPref(AntiTracking.qsBlockingPref, prefValue: true)
            self.engine.setPref(AntiTracking.enablePref, prefValue: true)
            self.engine.setPref("modules." + AntiTracking.moduleName + ".enabled", prefValue: enabled)
        }
    }
    
    public func setForceBlockEnabled(enabled: Bool) {
        dispatch_async(self.engine.dispatchQueue) {
            self.engine.setPref(AntiTracking.forceBlockPref, prefValue: enabled)
        }
    }
    
    public func getUnsafeRequestsCounter(tabId: Int) -> Int? {
        guard self.engine.isRunning() else {
            return nil
        }
        
        let blockingInfo = getTabBlockingInfo(tabId)
        let blockingInfoRequests = blockingInfo!["requests"]! as! Dictionary<String, Int>
        return blockingInfoRequests["unsafe"]
    }
    
    public func getTrackerDetails(tabId: Int) -> [(String, Int)] {
        var trackerDetails = [(String, Int)]()
        
        if let tabBlockInfo = getTabBlockingInfo(tabId) {
            
            if let companies = tabBlockInfo["companies"] as? [String: [String]],
                let allTrackers = tabBlockInfo["trackers"] as? [String: AnyObject] {
                for (company, trackers) in companies {
                    let badRequestsCount = getCompanyBadRequestsCount(trackers, allTrackers:allTrackers)
                    if badRequestsCount >= 0 {
                        trackerDetails.append((company, badRequestsCount))
                    }
                }
            }
        }
        return trackerDetails.sort { $0.1 == $1.1 ? $0.0.lowercaseString < $1.0.lowercaseString : $0.1 > $1.1 }
    }
    
    public func getTabBlockingInfo(tabId: Int) -> [NSObject : AnyObject]? {
        guard self.engine.isRunning() else {
            return nil
        }
        
        do {
            var argument = [AnyObject]()
            argument.append(tabId)
            if let tabUrl = webReuest.getUrlForTab(tabId) {
                argument.append(tabUrl)
            }
            let blockingInfo = try engine.systemLoader?.callFunctionOnModuleAttribute(AntiTracking.moduleName + "/attrack", attribute: ["default"], functionName: "getTabBlockingInfo", arguments: argument)
            return blockingInfo?.toDictionary()
        } catch let error as NSError {
            DebugLogger.log("<< Error in AntiTracking.getTabBlockingInfo: \(error)")
        }
        return nil
    }
    
    private func getCompanyBadRequestsCount(trackers: [String], allTrackers: [String: AnyObject]) -> Int {
        var badRequestsCount = 0
        for tracker in trackers {
            if let trackerStatistics = allTrackers[tracker] as? [String: Int] {
                if let badRequests = trackerStatistics["tokens_removed"] {
                    badRequestsCount += badRequests
                }
            }
        }
        return badRequestsCount
    }
    
    public func isWhitelisted(url: String) -> Bool? {
        guard self.engine.isRunning() else {
            return nil
        }
        
        do {
            let whitelisted = try engine.systemLoader?.callFunctionOnModuleAttribute(AntiTracking.moduleName + "/attrack", attribute: ["default"], functionName: "isSourceWhitelisted", arguments: [url])
            if let whitelisted =  whitelisted {
                return whitelisted.toBool()
            }
        } catch let error as NSError {
            DebugLogger.log("<< Error in AntiTracking.isWhitelisted: \(error)")
        }
        return false
    }
    
    public func addDomainToWhitelist(url: String) {
        do {
            try self.engine.systemLoader?.callFunctionOnModuleAttribute(AntiTracking.moduleName + "/attrack", attribute: ["default"], functionName: "addSourceDomainToWhitelist", arguments: [url])
        } catch let error as NSError {
            DebugLogger.log("<< Error in AntiTracking.addDomainToWhitelist: \(error)")
        }
    }
    
    public func removeDomainFromWhitelist(url: String) {
        do {
            try self.engine.systemLoader?.callFunctionOnModuleAttribute(AntiTracking.moduleName + "/attrack", attribute: ["default"], functionName: "removeSourceDomainFromWhitelist", arguments: [url])
        } catch let error as NSError {
            DebugLogger.log("<< Error in AntiTracking.removeDomainFromWhitelist: \(error)")
        }
    }
}
