//
//  HTTPFetcher.swift
//  cnBetaReader
//
//  Created by Shilei Tian on 05/03/2017.
//  Copyright © 2017 TSL. All rights reserved.
//

import Kanna

var loadMoreToken: String? = nil

class HTTPFetcher {
  
  // MARK: - APIs
  
  // Fetch home page
  func fetchHomePage(completionHandler: @escaping ()->Void) {
    let urlString = "http://www.cnbeta.com"
    
    if let url = URL(string: urlString) {
      let task = URLSession.shared.dataTask(with: url) {
        (data, response, error) in
        if let error = error {
          print("Error: \(error)")
        } else if let data = data {
          if let html = String(data: data, encoding: .utf8), let doc = HTML(html: html, encoding: .utf8) {
            // Set the load more token
            let loadMoreTokenElement = doc.at_xpath("//meta[@name='csrf-token']")
            if let homeMoreTokenElement = loadMoreTokenElement {
              loadMoreToken = homeMoreTokenElement.content!
            } else {
              print("Fatal error: fail to load csrf-token.")
              return;
            }
            
            // Set the regex for id, time and comment count
            var regexID: NSRegularExpression?, regexTime: NSRegularExpression?, regexCommentCount: NSRegularExpression?
            do {
              regexID = try NSRegularExpression(pattern: "\\d+", options: [.caseInsensitive])
              regexTime = try NSRegularExpression(pattern: "\\d\\d-\\d\\d \\d\\d:\\d\\d", options: [.caseInsensitive])
              regexCommentCount = try NSRegularExpression(pattern: "\\d+(?=个意见)", options: [.caseInsensitive])
            } catch {
              regexID = nil
              regexTime = nil
              regexCommentCount = nil
            }
            
            // Process the downloaded item div
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
              for itemDiv in doc.xpath("//div[@class='items-area']/div[@class='item']") {
                let article = ArticleMO(context: appDelegate.persistentContainer.viewContext)
                let urlElement = itemDiv.at_xpath(".//dl/dt/a")
                if let urlElement = urlElement {
                  let url = urlElement["href"]!
                  article.url = url
                  article.title = urlElement.content!
                  if let idMatchResult = regexID?.firstMatch(in: url, options: [], range: NSMakeRange(0, url.characters.count)) {
                    article.id = (url as NSString).substring(with: idMatchResult.range)
                  } else {
                    print("Fatal error: the website structure has changed.")
                    return;
                  }
                } else {
                  print("Fatal error: the website structure has changed.")
                  return;
                }
                
                if let statusElement = itemDiv.at_xpath(".//ul[@class='status']/li") {
                  let statusString = statusElement.content!
                  if let timeMatchResult = regexTime?.firstMatch(in: statusString, options: [], range: NSMakeRange(0, statusString.characters.count)),
                    let commentCountMathResult = regexCommentCount?.firstMatch(in: statusString, options: [], range: NSMakeRange(0, statusString.characters.count)) {
                    article.time = (statusString as NSString).substring(with: timeMatchResult.range)
                    article.commentCount = (statusString as NSString).substring(with: commentCountMathResult.range)
                  }
                } else {
                  print("Fatal error: the website structure has changed.")
                  return;
                }
                
                if let thumbDiv = itemDiv.at_xpath(".//img") {
                  article.thumbURL = thumbDiv["src"]!
                } else {
                  print("Fatal error: the website structure has changed.")
                  return;
                }
                appDelegate.saveContext()
              }
              completionHandler()
            }
          }
        }
      }
      task.resume()
    }
  }
  
  // Fetch article content
  func fetchContent(id: String, articleURL: String, completionHandler: @escaping ()->Void) {
    if let url = URL(string: articleURL) {
      let task = URLSession.shared.dataTask(with: url) {
        (data, response, error) in
        if let error = error {
          print("Fatal error: \(error)")
          return;
        } else if let data = data {
          if let html = String(data: data, encoding: .utf8), let doc = HTML(html: html, encoding: .utf8) {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
              let articleContent = ArticleContentMO(context: appDelegate.persistentContainer.viewContext)
              articleContent.id = id
              if let summary = doc.at_xpath("//div[@class='article-summary']//p") {
                articleContent.summary = String()
                articleContent.summary = summary.toHTML!
              } else {
                print("Failed to parse the summary…")
                return
              }
              articleContent.content = String()
              let paras = doc.xpath("//div[@class='article-content']")
              for para in paras {
                articleContent.content!.append(para.toHTML!)
              }
              appDelegate.saveContext()
              completionHandler()
            }
          }
        }
      }
      task.resume()
    }
  }
}
