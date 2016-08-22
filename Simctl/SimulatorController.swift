//
//  SimulatorController.swift
//  Simctl
//
//  Created by silvia on 20/08/2016.
//  Copyright © 2016 e34. All rights reserved.
//


import BrightFutures
import Alamofire

extension FBSimulatorPool {
    func simulatorWithProcessIdentifier(processIdentifier: pid_t) -> FBSimulator? {
        let simulators = set.allSimulators
        return simulators.filter({$0.launchdProcess?.processIdentifier == processIdentifier}).first
    }
}

class SimulatorController {
    
    static let sharedInstance = SimulatorController()
    let control: FBSimulatorControl?
    var ports = [String:String]()
    init() {
        
        let options: FBSimulatorManagementOptions  = [FBSimulatorManagementOptions.KillSpuriousSimulatorsOnFirstStart]
        let configuration = FBSimulatorControlConfiguration(deviceSetPath: FBSimulatorControlConfiguration.defaultDeviceSetPath(), options: options)
        control = try? FBSimulatorControl.withConfiguration(configuration)
    }
    
    func launchSimulator(config: FBSimulatorConfiguration = FBSimulatorConfiguration.iPhone6()) throws -> String? {
        let allocationOptions = FBSimulatorAllocationOptions.Create
        if let simulator = try self.control?.pool.allocateSimulatorWithConfiguration(config, options: allocationOptions) {
            let task = NSTask()
            task.launchPath = NSBundle.mainBundle().pathForResource("fbsimctl", ofType:  "")!
            task.arguments = [simulator.udid, "boot"]
            task.launch()
            task.waitUntilExit()
            return simulator.udid
        } else {
            throw NSError(domain: "Simctl", code: 500, userInfo:  [NSLocalizedDescriptionKey : "Couldn't allocate simulator"])
        }
    }
    
    func launchWebDriverAgent(simulatorUdid: String) {
        let port =  String(NSNumber.randomNumber(15000, max: 30000))
        ports[simulatorUdid] = port
        
        print("*****Starting WebDriverAgent on port \(port)")
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let task = NSTask()
            task.launchPath = NSBundle.mainBundle().pathForResource("fbsimctl", ofType:  "")!
            task.arguments = [simulatorUdid, "launch_xctest", "--test-timeout", "900.0", "\(NSBundle.mainBundle().pathForResource("WebDriverAgentRunner-Runner", ofType: "app")!)/PlugIns/WebDriverAgentRunner.xctest", "com.apple.mobilesafari", "--port" , port, "--listen"]
            task.launch() //never going to finish
        }
    }
    
    typealias Retryable = (success: JSON -> Void, failure: NSError -> Void) -> Void
    
    func retry(numberOfTimes: Int, task: () -> Retryable, success: JSON -> Void, failure: NSError -> Void) {
        task()(success: success, failure: { error in
            if numberOfTimes > 1 {
                sleep(4)
                self.retry(numberOfTimes - 1, task: task, success: success, failure: failure)
            } else {
                failure(error)
            }
        })
    }
    
    
    func startTestSession(simulatorUdid: String) -> Future<JSON, NSError> {
        let promise = Promise<JSON, NSError>()
        retry(10, task: { self.pokeWebAgent(simulatorUdid) },
              success: { data in
                promise.success(data)
            },
              failure: { err in
                promise.failure(err)
            }
        )
        return promise.future
    }
    
    private func pokeWebAgent(simulatorUdid: String) -> Retryable {
        return {success, failure in
            //todo handle
            let host = "http://localhost:\(self.ports[simulatorUdid]!)"
            let sessionUrl = "\(host)/session"
            let inspectorUrl = "\(host)/inspector"
            let appPath = NSBundle.mainBundle().pathForResource("TableSearch", ofType: "app")!
            let parameters = [
                "desiredCapabilities": [
                    "bundleId": "com.example.apple-samplecode.TableSearch",
                    "app": appPath
                ]
            ]
            Alamofire.request(.POST, sessionUrl, parameters: parameters, encoding:.JSON)
                .validate()
                .responseJSON { (response) -> Void in
                    guard response.result.isSuccess, var value = response.result.value as? [String: AnyObject] else {
                        failure(NSError(domain: "Simctl", code: 500, userInfo: [NSLocalizedDescriptionKey : "Couldn't contact WebDriverAgent"]))
                        return
                    }
                    value["inspectorUrl"] = inspectorUrl
                    value["webdriverUrl"] = "\(sessionUrl)/\(value["sessionId"]!)"
                    let response = try? JSON.encode(value)
                    success(response!)
            }
        }
    }
    
    func killSimulator(processIdentifier: pid_t) throws {
        if let simulator = self.control?.pool.simulatorWithProcessIdentifier(processIdentifier) {
            try self.control?.pool.freeSimulator(simulator)
        }
    }
    
    func killAllSimulators() throws {
        //todo does not actually work
        try self.control?.set.killAll()
    }
    
}

extension NSNumber {
    class func randomNumber(min: UInt32, max: UInt32) -> Int{
        return Int(arc4random_uniform(max) + min)
    }
}