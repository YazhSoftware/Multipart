# Multipart
=========

![](https://img.shields.io/badge/carthage-compatible-brightgreen.svg)


# Introduction
------------

// sample doc upload call.
    let request = UploadDownloadService()
    request.param = ["userToken"  : "*******", "appName"    : "****"]
    request.fileName = "***.jpg"
    let path = NSBundle.mainBundle().pathForResource("***", ofType: "jpg") as String!
    let url = NSURL(fileURLWithPath: path)
    request.fileData = NSData(contentsOfURL: url)!
    request.serviceCall(.Upload, completion: { response, failure in
      
      print(response)
      })

Configuration
------------


  Create configuration plist file with following information.

SOA_Username : ******
SOA_Password : ******

Webservice_url_Webupload : ******
Webservice_url_Webdownload : *****