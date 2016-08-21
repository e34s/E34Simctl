import Foundation
import GCDWebServer
import BrightFutures

protocol RequestHandler {
    func handle(request : JSON) -> Future<JSON, NSError>;
}


@objc class WebServer : NSObject {
    private let webserver : GCDWebServer!
    private let portNumber : UInt
    
    private let handlers = [ ["method":"POST","path":"/simulator/launch", "handler":LaunchRequestHandler()],
                             ["method":"POST","path":"/simulator/kill", "handler" : KillRequestHandler()],
                             ["method":"PUT","path":"/control", "handler" : ControlHandler()]]
    
    init(port: UInt) {
        webserver = GCDWebServer()
        portNumber = port
        super.init()
        self.addHandlers()
    }
    
    private func addHandlers()  {
        for handlerMapping in handlers {
            let method = handlerMapping["method"] as! String
            let path = handlerMapping["path"] as! String
            let handler = handlerMapping["handler"] as! RequestHandler
            self.addHandler(method, path: path, handler: handler)
        }
    }
    
    private func addHandler(method: String, path: String, handler: RequestHandler) {
        webserver.addHandlerForMethod(method, path: path, requestClass: GCDWebServerDataRequest.self) { (request, completionCallback) -> Void in
            self .handleRequest(request, handler: handler, completionBlock: completionCallback)
        }
    }
    

    
    private func handleRequest(request : GCDWebServerRequest, handler : RequestHandler, completionBlock : GCDWebServerCompletionBlock) {
        
        let dataRequest = request as! GCDWebServerDataRequest
        do {
            let map2 = try JSON.fromData(dataRequest.data)
            handler.handle(map2)
                .onSuccess(callback: { res in
                    let response = try? GCDWebServerDataResponse(data: JSON.toData(res), contentType: "application/json")
                    response?.statusCode = 200
                    completionBlock(response)
                })
                .onFailure(callback: {err in
                    let response = self.dataResponseForError(err)
                    completionBlock(response)
                })
        } catch let error as NSError {
            completionBlock(self.dataResponseForError(error))
        }
    }
    
    private func dataResponseForError(error :NSError) -> GCDWebServerDataResponse {
        let errorResponse = ["success":"false","error":error.localizedDescription]
        do {
            let dataResponse = try GCDWebServerDataResponse(data: NSJSONSerialization.dataWithJSONObject(errorResponse, options: NSJSONWritingOptions()) , contentType: "application/json")
            dataResponse.statusCode = 500
            return dataResponse
        } catch {
            return GCDWebServerDataResponse(statusCode: 500)
        }
    }
    
    func startServer()  {
        webserver.startWithPort(portNumber, bonjourName: "e34.simctl")
    }
    
}


