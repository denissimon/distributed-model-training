//
//  AppAPI.swift
//  DMT
//
//  Created by Denis Simon on 10.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation

enum AppAPI {
    case backupModel(id: String)
    case restoreModel(id: String)
    case changeModelId(ids: (old: String, new: String))
}

extension AppAPI: EndpointType {
    
    var method: Method {
        switch self {
        case .backupModel:
            return .POST
        case .restoreModel:
            return .GET
        case .changeModelId:
            return .PUT
        }
    }
    
    var baseURL: String {
        return AppConstants.AppAPI.BaseURL
    }
    
    var path: String {
        switch self {
        case .backupModel(let id):
            return "/backupModel&apiKey=\(AppConstants.AppAPI.ApiKey)&modelId=\(id)"
        case .restoreModel(let id):
           return "/restoreModel&apiKey=\(AppConstants.AppAPI.ApiKey)&modelId=\(id)"
        case .changeModelId(let ids):
            return "/changeModelId&apiKey=\(AppConstants.AppAPI.ApiKey)&oldId=\(ids.old)&newId=\(ids.new)"
        }
    }
    
    var constructedURL: URL? {
        return URL(string: self.baseURL + self.path)
    }
}

