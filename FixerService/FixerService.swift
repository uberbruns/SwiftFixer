//
//  FixerTypes.swift
//  FixerService
//
//  Created by Karsten Bruns on 22/09/15.
//  Copyright © 2015 grandcentrix GmbH. All rights reserved.
//

import Foundation


// MARK: - Prototcols -
// MARK: JSON

typealias NSJSONObject = [String:AnyObject]


protocol JSONInitializable {
    init?(json: NSJSONObject)
}



// MARK: Request

protocol FixerRequest {
    associatedtype Result: JSONInitializable
    var path: String { get }
    var parameters: [String:String] { get }
}


extension FixerRequest {
    
    var urlRequest: NSURLRequest? {
        
        let urlComponent = NSURLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = "api.fixer.io"
        urlComponent.path = self.path
        urlComponent.query = parameters.count > 0 ? parameters.map({ name, value in name + "=" + value }).joinWithSeparator("&") : nil
        
        guard let url = urlComponent.URL else {
            return nil
        }
        
        return NSURLRequest(URL: url)
    }
    
}


// MARK: - Types -
// MARK: Response

enum FixerReponse<T> : ErrorType {
    case Result(T)
    case Error(FixerReponseError)
}


enum FixerReponseError : ErrorType {
    case InvalidRequest
    case InvalidJSON
    case DecodingError
    case NoInternet
    case UnknownError
}


// MARK: Results

struct Rates {
    let base: String
    let date: String
    let rates: [String:Double]
}


extension Rates : JSONInitializable {
    
    init?(json: NSJSONObject) {
        guard let base = json["base"] as? String,
            let date = json["date"] as? String ,
            let rates = json["rates"] as? [String:Double] else {
                return nil
        }
        self.base = base
        self.date = date
        self.rates = rates
    }
    
}



// MARK: Requests

struct LatestRequest : FixerRequest {
    
    typealias Result = Rates
    
    let path = "/latest"
    let parameters: [String:String]
    
    init(base: String? = nil, symbols: String...) {
        var parameters = [String:String]()
        if let base = base {
            parameters["base"] = base
        }
        if symbols.count > 0 {
            parameters["symbols"] = symbols.joinWithSeparator(",")
        }
        self.parameters = parameters
    }
}


struct HistoricalRatesRequest : FixerRequest {
    
    typealias Result = Rates
    
    let path: String
    let parameters: [String:String]
    
    init(date: String, base: String? = nil, symbols: String...) {
        var parameters = [String:String]()
        if let base = base {
            parameters["base"] = base
        }
        if symbols.count > 0 {
            parameters["symbols"] = symbols.joinWithSeparator(",")
        }
        self.parameters = parameters
        self.path = "/" + date
    }
    
}


// MARK: - Service -

class FixerService {
    
    let session = NSURLSession.sharedSession()
    
    func runRequest<R: FixerRequest>(request: R, completionHandler: (response: FixerReponse<R.Result>) -> Void) {
        
        guard let urlRequest = request.urlRequest else {
            completionHandler(response: .Error(.InvalidRequest))
            return
        }
        
        let task = session.dataTaskWithRequest(urlRequest) { (data, response, error) in
            
            let mainQueue = dispatch_get_main_queue()
            let backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
            
            dispatch_async(backgroundQueue) {
                
                typealias Response = FixerReponse<R.Result>
                
                do {
                    if let error = error {
                        throw error
                    }
                    
                    guard let data = data else {
                        throw Response.Error(.UnknownError)
                    }
                    
                    let json = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                    
                    guard let jsonObject = json as? NSJSONObject else {
                        throw Response.Error(.InvalidJSON)
                    }
                    
                    guard let result = R.Result(json: jsonObject) else {
                        throw Response.Error(.DecodingError)
                    }
                    
                    dispatch_async(mainQueue) {
                        completionHandler(response: .Result(result))
                    }
                    
                } catch let error as NSError where error.code == Int(CFNetworkErrors.CFURLErrorNotConnectedToInternet.rawValue) {
                    
                    dispatch_async(mainQueue) {
                        completionHandler(response: .Error(.NoInternet))
                    }
                    
                } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == 3840 {
                    
                    dispatch_async(mainQueue) {
                        completionHandler(response: .Error(.InvalidJSON))
                    }
                    
                } catch let error as Response {
                    
                    dispatch_async(mainQueue) {
                        completionHandler(response: error)
                    }
                    
                } catch {
                    
                    dispatch_async(mainQueue) {
                        completionHandler(response: .Error(.UnknownError))
                    }
                }
            }
        }
        
        task.resume()
    }
    
}