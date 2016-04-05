//
//  UploadDownloadService.swift
//  PropertySalesSystem
//
//  Created by karuna on 4/3/16.
//  Copyright © 2016 MAF. All rights reserved.
//

import UIKit
import MobileCoreServices

private let kKeypath = "countOfBytesReceived"
private let kContentDisposition = "Content-Disposition: form-data;"
private let kWebservice_url_Webupload = "Webservice_url_Webupload"
private let kWebservice_url_Webdownload = "Webservice_url_Webdownload"

private let kSOAUsername = "SOA_Username"
private let kSOAPassword = "SOA_Password"

let kMethodGet = "GET"
let kMethodPost = "POST"
let kAuthorizationKey = "Authorization"
let kContentTypeKey = "Content-Type"
let kContentLengthKey = "Content-Length"

enum ServiceType: Int {
  
  case Upload = 0
  case Download
}

class UploadDownloadService: NSObject {
  
  private var myContext = 0
  var task: NSURLSessionDataTask?
  let circularProgress = GradientCircularProgress()
  var param: [String: String]?
  var fileData = NSData()
  var fileName = String()
  
  let styleList: [(String, StyleProperty)] = [
    ("Style.swift", Style()),
    ("BlueDarkStyle.swift", BlueDarkStyle()),
    ("OrangeClearStyle.swift", OrangeClearStyle()),
    ("GreenLightStyle.swift", GreenLightStyle()),
    ("BlueIndicatorStyle.swift", BlueIndicatorStyle()),
    ]
  
 
  func serviceCall(type : ServiceType, completion: (response: NSDictionary?, fauilure: String?) -> ()) {
    let request = type == .Upload ? createUploadRequest() : createDownloadRequest()
    
    task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
      
      if error != nil {
        completion(response: nil ,fauilure:error?.description)
        return
      }
      // if response was JSON, then parse it
      
      do {
        if let responseDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary {
          completion(response: responseDictionary ,fauilure:nil)
        }
      } catch {
        let responseString = String(data: data!, encoding: NSUTF8StringEncoding)
        completion(response: nil ,fauilure:responseString)

      }
      self.circularProgress.dismiss()
      self.task!.removeObserver(self, forKeyPath: kKeypath)

    }
    task!.resume()
    task!.addObserver(self, forKeyPath: kKeypath, options: .New, context: &myContext)
    
  }

  private func updateProgressTo(countOfBytesReceived:Int64, animated:Bool) {
    let downloadSize = self.task!.countOfBytesExpectedToReceive;
    let progress = (downloadSize == 0) ? 0 : Float(countOfBytesReceived) / Float(self.task!.countOfBytesExpectedToReceive)
    circularProgress.showAtRatio(display: true, style: styleList[0].1)
    circularProgress.updateRatio(CGFloat(progress))
    if(progress == 1) {
      circularProgress.dismiss()
    }
  }
  
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if context == &myContext {
      dispatch_async(dispatch_get_main_queue(),{ [weak self] () -> () in
        if (keyPath == kKeypath) {
          self?.updateProgressTo(self?.task?.countOfBytesReceived ?? 0, animated:true)
        }
      })
    } else {
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
  }
  
  
  /// Create download request
  ///
  /// - parameter userToken:   The userToken to be passed to web service
  /// - parameter appName: The appName to be passed to web service
  ///
  /// - returns:            The NSURLRequest that was created
  
  func createDownloadRequest () -> NSURLRequest {
    
    let boundary = generateBoundaryString()
    let url = NSURL(string: self.getValueForKey(kWebservice_url_Webdownload))
    let request = NSMutableURLRequest(URL: url ?? NSURL())
    request.HTTPMethod = kMethodGet
    request.HTTPBody = createBodyWithParameters(param, filePathKey: nil, boundary: boundary)
    soaAuthentication(request)
    return request
  }
  
  /// Create upload request
  ///
  /// - parameter userToken:   The userToken to be passed to web service
  /// - parameter appName: The appName to be passed to web service
  ///
  /// - returns:            The NSURLRequest that was created
  
  func createUploadRequest () -> NSURLRequest {
    
    let boundary = generateBoundaryString()
    
    let url = NSURL(string: self.getValueForKey(kWebservice_url_Webupload))!
    let request = NSMutableURLRequest(URL: url)
    request.HTTPMethod = kMethodPost
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: kContentTypeKey)
    
    request.HTTPBody = createBodyWithParameters(param, filePathKey: "file", boundary: boundary)
    soaAuthentication(request)
    return request
  }
  
  /// Adding SOA authentication credentials
  ///
  func soaAuthentication(request: NSMutableURLRequest) {
    if let username = self.getValueForKey(kSOAUsername) ,let password = self.getValueForKey(kSOAPassword) {
      let authStr: String = "\(username):\(password)"
      let authData: NSData = authStr.dataUsingEncoding(NSUTF8StringEncoding)!
      let authValue: String = "Basic \(authData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength))"
      request.addValue(authValue, forHTTPHeaderField: kAuthorizationKey)
    }
  }
  
  
  /// Create body of the multipart/form-data request
  ///
  /// - parameter parameters:   The optional dictionary containing keys and values to be passed to web service
  /// - parameter filePathKey:  The optional field name to be used when uploading files. If you supply paths, you must supply filePathKey, too.
  /// - parameter paths:        The optional array of file paths of the files to be uploaded
  /// - parameter boundary:     The multipart/form-data boundary
  ///
  /// - returns:                The NSData of the body of the request
  
  func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, boundary: String) -> NSData {
    let body = NSMutableData()
    
    if parameters != nil {
      for (key, value) in parameters! {
        body.appendString("--\(boundary)\r\n")
        body.appendString("\(kContentDisposition) name=\"\(key)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
      }
    }
    if let fileKey = filePathKey {

      let mimetype = mimeTypeForPath()
      body.appendString("--\(boundary)\r\n")
      body.appendString("\(kContentDisposition) name=\"\(fileKey)\"; filename=\"\(fileName.lastPathComponent)\"\r\n")
      body.appendString("\(kContentTypeKey): \(mimetype)\r\n\r\n")
      body.appendData(fileData)
      body.appendString("\r\n")
    }
    body.appendString("--\(boundary)--\r\n")
    return body
  }
  
  /// Create boundary string for multipart/form-data request
  ///
  /// - returns:            The boundary string that consists of "Boundary-" followed by a UUID string.
  
  func generateBoundaryString() -> String {
    return "Boundary-\(NSUUID().UUIDString)"
  }
  
  /// Determine mime type on the basis of extension of a file.
  ///
  /// This requires MobileCoreServices framework.
  ///
  /// - parameter path:         The path of the file for which we are going to determine the mime type.
  ///
  /// - returns:                Returns the mime type if successful. Returns application/octet-stream if unable to determine mime type.
  
  func mimeTypeForPath() -> String {
    let pathExtension = fileName.pathExtension
    
    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
      if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
        return mimetype as String
      }
    }
    return "application/octet-stream";
  }
  
  func getValueForKey(key:String!) -> String! {
    var dictionaryPlist : NSDictionary?

    let filePath = NSBundle.mainBundle().pathForResource("Configuration", ofType: "plist")
    if dictionaryPlist == nil {
      dictionaryPlist = NSDictionary(contentsOfFile:(filePath)!)
    }
    return dictionaryPlist!.valueForKey(key) as! String
  }

}

extension NSMutableData {
  
  /// Append string to NSMutableData
  ///
  /// Rather than littering my code with calls to `dataUsingEncoding` to convert strings to NSData, and then add that data to the NSMutableData, this wraps it in a nice convenient little extension to NSMutableData. This converts using UTF-8.
  ///
  /// - parameter string:       The string to be added to the `NSMutableData`.
  
  func appendString(string: String) {
    let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
    appendData(data!)
  }
}
