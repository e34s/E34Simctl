//
//  KillRequestHandler.swift
//  FBSimulatorClient
//
//  Created by Tapan Thaker on 08/11/15.
//  Copyright (c) 2015 TT. All rights reserved.
//

import Foundation
import BrightFutures

class KillRequestHandler: RequestHandler {
    func handle(request: JSON) -> Future<JSON, NSError> {
        do {
            let processIdentifier = try request.getValue("processIdentifier").getString()
            if let identifier = Int32(processIdentifier)  {
                try SimulatorController.sharedInstance.killSimulator(identifier)
                return try Future(value: JSON.encode(["success":"true", "killed": processIdentifier]))
            }
        } catch {}
        return Future(error: NSError(domain: "Simctl", code: 500, userInfo:  [NSLocalizedDescriptionKey : "Could not kill specific simulator"]))
    }
    
}
