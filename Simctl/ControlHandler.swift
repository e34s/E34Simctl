//
//  ExitHandler.swift
//  FBSimulatorClient
//
//  Created by Tapan Thaker on 08/11/15.
//  Copyright (c) 2015 TT. All rights reserved.
//

import Foundation
import BrightFutures

class ControlHandler: RequestHandler {
    func handle(request: JSON) -> Future<JSON, NSError> {
        do {
            let command = try request.getValue("command").getString()
            switch command {
            case "quit":
                do {
                    try SimulatorController.sharedInstance.killAllSimulators()
                    exit(0)
                } catch {
                    exit(1)
                }
            default:
                return Future(error: NSError(domain: "Simctl", code: 500, userInfo: [NSLocalizedDescriptionKey : "No such command: \(command)"]))
            }
        } catch {
            return Future(error: NSError(domain: "Simctl", code: 500, userInfo: [NSLocalizedDescriptionKey : "Command parameter missing"]))
        }
    }
}
