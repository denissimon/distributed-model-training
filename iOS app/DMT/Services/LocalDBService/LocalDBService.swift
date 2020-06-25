//
//  LocalDBService.swift
//  DMT
//
//  Created by Denis Simon on 11.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation

let defaults = UserDefaults.standard

public class LocalDBService {
    
    static func set<T>(value: T, forKey: String) {
        if !forKey.isEmpty {
            defaults.set(value, forKey: forKey)
        }
    }
    
    static func get(forKey: String) -> String? {
        var value: String? = nil
        
        if !forKey.isEmpty {
            value = defaults.string(forKey: forKey)
        }
        
        return value
    }
    
    static func remove(forKey: String) {
        if let keyValue = defaults.string(forKey: forKey) {
            defaults.removeObject(forKey: keyValue)
        }
    }
}
