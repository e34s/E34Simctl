//
//  SimulatorController.swift
//  Simctl
//
//  Created by silvia on 20/08/2016.
//  Copyright © 2016 e34. All rights reserved.
//


import BrightFutures

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
            task.launchPath = "fbsimctl"
            task.arguments = [simulator.udid, "boot"]
            task.launch()
            task.waitUntilExit()
            return simulator.udid
        } else {
            throw NSError(domain: "Simctl", code: 500, userInfo:  [NSLocalizedDescriptionKey : "Couldn't allocate simulator"])
        }
    }
    
    func launchWebDriverAgent(sim: String) {
        ports[sim] = String(NSNumber.randomNumber(15000, max: 30000))
        
        print("*****Starting WebDriverAgent on port \(ports[sim]!)")
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let task = NSTask()
            task.launchPath = "fbsimctl"
            task.arguments = [sim, "launch_xctest", "--test-timeout", "900.0", "/Users/silvia/Library/Developer/Xcode/DerivedData/build/Products/Debug-iphonesimulator/WebDriverAgentRunner-Runner.app/PlugIns/WebDriverAgentRunner.xctest", "com.apple.mobilesafari", "--port" , self.ports[sim]!, "--listen"]
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

            let request = NSMutableURLRequest(URL: NSURL(string: sessionUrl)!)
            request.HTTPMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let postString = "{\"desiredCapabilities\":{\"bundleId\":\"com.example.apple-samplecode.TableSearch\", \"app\":\"/Users/silvia/Development/workspace/e34/TableSearch.app\"}}"
            request.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding)
            NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { data, response, error in
                guard error == nil && data != nil else {
                    failure(error!)
                    return
                }
                
                if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {
                    failure(NSError(domain: "Simctl", code: httpStatus.statusCode, userInfo: [NSLocalizedDescriptionKey : "Received weird status"]))
                }
                do {
                    var object = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as! [String:AnyObject]
                    object["inspectorUrl"] = inspectorUrl
                    object["webdriverUrl"] = "\(sessionUrl)/\(object["sessionId"]!)"
                    
                    let response = try JSON.encode(object)
                    success(response)
                } catch {
                    failure(NSError(domain: "Simctl", code: 3, userInfo: [NSLocalizedDescriptionKey : "Error parsing json"]))
                }
                
            }).resume()
        }
    }

    func killSimulator(processIdentifier: pid_t) throws {
        if let simulator = self.control?.pool.simulatorWithProcessIdentifier(processIdentifier) {
            try self.control?.pool.freeSimulator(simulator)
        }
    }
    
    func killAllSimulators() throws {
        try self.control?.set.killAll()
    }

}

extension NSNumber {
    class func randomNumber(min: UInt32, max: UInt32) -> Int{
        return Int(arc4random_uniform(max) + min)
    }
}