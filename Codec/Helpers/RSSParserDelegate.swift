//
//  RSSParserDelegate.swift
//  Codec
//
//  Created by Jacob Peddicord on 7/3/24.
//

import Foundation

class RSSParserDelegate: NSObject, XMLParserDelegate {
    var channelImageURL: String?
    private var currentElement = ""
    private var isInChannelImageElement = false
    private var isInURLElement = false
    private var isInItemElement = false
    private var depth = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        depth += 1
        currentElement = elementName
        
        if elementName == "item" {
            isInItemElement = true
        }
        
        if !isInItemElement {
            if elementName == "image" && depth == 3 { // Ensuring we're at channel level
                isInChannelImageElement = true
            } else if elementName == "url" && isInChannelImageElement {
                isInURLElement = true
            } else if elementName == "itunes:image", let href = attributeDict["href"] {
                channelImageURL = href
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItemElement = false
        }
        if elementName == "image" {
            isInChannelImageElement = false
        }
        if elementName == "url" {
            isInURLElement = false
        }
        depth -= 1
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !isInItemElement && isInURLElement && isInChannelImageElement && channelImageURL == nil {
            channelImageURL = string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
