//
//  LaunchRequestHandler.swift
//  FBSimulatorClient
//
//  Created by Tapan Thaker on 08/11/15.
//  Copyright (c) 2015 TT. All rights reserved.
//

import Foundation
import BrightFutures

class LaunchRequestHandler : RequestHandler {
    
    func handle(request: JSON) -> Future<JSON, NSError> {
        let promise = Promise<JSON, NSError>()
        do {
            let simulator = try request.getValue("simulator").getString()
            
            if let simulatorUdid = try SimulatorController.sharedInstance.launchSimulator(FBSimulatorConfiguration.withDeviceNamed(simulator)!) {
                SimulatorController.sharedInstance.launchWebDriverAgent(simulatorUdid)
                SimulatorController.sharedInstance.startTestSession(simulatorUdid).onSuccess(callback: { res in
                      promise.success(res)
                }).onFailure(callback: {err in  promise.failure(err)})
            }
        } catch {
            promise.failure(NSError(domain: "Simctl", code: 500, userInfo:  [NSLocalizedDescriptionKey : "Failed to launch simulator"]))
        }
        return promise.future
    }
    
    

}
