//
//  ModelBackupViewModel.swift
//  DMT
//
//  Created by Denis Simon on 20.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation
import SwiftEvents

class ModelBackupViewModel {
    
    let modelBackup = ModelBackup.shared
    
    var isActionGoing = false
    
    init() {
       subscribeOnEvents()
    }
    
    func subscribeOnEvents() {
        // Delegates
        modelBackup.onActionCompleted.addSubscriber(target: self, handler: { (self, _) in
            self.isActionGoing = false
        })
    }
    
    func onBackupSwitchChanged(_ value: Bool) {
        if value {
            LocalDBService.set(value: "On", forKey: AppConstants.UserDefaults.modelBackupKey)
        } else {
            LocalDBService.set(value: "Off", forKey: AppConstants.UserDefaults.modelBackupKey)
        }
    }
    
    func backupModel() {
        isActionGoing = true
        modelBackup.backupModel(completion: nil)
    }
    
    func changeModelId(newModelId: String) {
        if !newModelId.isEmpty {
            isActionGoing = true
            modelBackup.changeModelId(newModelId: newModelId)
        }
    }
    
    func restoreModel(modelId: String) {
        if !modelId.isEmpty {
            isActionGoing = true
            modelBackup.restoreModel(modelId: modelId)
        }
    }
}

