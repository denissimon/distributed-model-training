//
//  ModelBackup.swift
//  DMT
//
//  Created by Denis Simon on 20.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation
import SwiftEvents
import Zip

public class ModelBackup {
    
    static let shared = ModelBackup()
    
    let networkService = NetworkService()
    
    // Event-based delegation
    let showAlert = Event<String>()
    let onActionCompleted = Event<Bool?>() // has 2 subscribers
    // Event-based bindings
    let activityIndicatorVisibility = Observable<Bool>(false)
    
    private(set) var modelId: String
    
    private init() {
        if let modelId = LocalDBService.get(forKey: AppConstants.UserDefaults.modelIdKey) {
            self.modelId = modelId
        } else {
            modelId = UUID().description
            saveModelIdToLocalDB(modelId)
            saveModelBackupSettingToLocalDB(true)
        }
    }
    
    private func saveModelIdToLocalDB(_ modelId: String) {
        print("saveModelIdToLocalDB modelId:",modelId)
        LocalDBService.set(value: modelId, forKey: AppConstants.UserDefaults.modelIdKey)
    }
    
    func saveModelBackupSettingToLocalDB(_ value: Bool) {
        print("saveModelBackupSettingToLocalDB")
        if value {
            LocalDBService.set(value: "On", forKey: AppConstants.UserDefaults.modelBackupKey)
        } else {
            LocalDBService.set(value: "Off", forKey: AppConstants.UserDefaults.modelBackupKey)
        }
    }
    
    private func showErrorToast(_ msg: String = "") {
        DispatchQueue.main.async {
            if msg.isEmpty {
                self.showAlert.trigger("An error occurred")
            } else {
                self.showAlert.trigger(msg)
            }
            self.activityIndicatorVisibility.value = false
            self.onActionCompleted.trigger(nil)
        }
    }
    
    // PUT request to change/replace the value of model id
    func changeModelId(newModelId: String) {
        if newModelId.isEmpty { return }
        
        activityIndicatorVisibility.value = true
        
        guard let currentModelId = LocalDBService.get(forKey: AppConstants.UserDefaults.modelIdKey) else {
            showErrorToast()
            return
        }
        
        if newModelId == currentModelId {
            showErrorToast()
            return
        }
        
        guard let newModelIdEscaped = newModelId.encodeURIComponent(),
        let currentModelIdEscaped = currentModelId.encodeURIComponent() else {
            showErrorToast()
            return
        }
        
        let endpoint = AppAPI.changeModelId(ids: (old: currentModelIdEscaped, new: newModelIdEscaped))
        
        networkService.requestEndpoint(endpoint) { [weak self] (result) in
            guard let self = self else { return }
                
            switch result {
            case .done(let responceStatusCode):
                let statusCodeStr = String.init(data: responceStatusCode, encoding: String.Encoding.utf8)
                let statusCode = Int.init(statusCodeStr ?? "")
                if statusCode == 200 {
                    self.modelId = newModelId
                    self.saveModelIdToLocalDB(newModelId)
                    self.activityIndicatorVisibility.value = false
                    self.onActionCompleted.trigger(nil)
                } else if statusCode == 404 {
                    self.backupModel(completion: {
                        self.changeModelId(newModelId: newModelId)
                    })
                } else if statusCode == 403 {
                    self.showErrorToast("Model with this id already exists")
                } else {
                    self.showErrorToast()
                }
            case .error(let error):
                if error != nil {
                    self.showErrorToast(error!.localizedDescription)
                } else {
                    self.showErrorToast()
                }
            }
        }
    }
    
    func getModelURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("s4tf_updatable_model").appendingPathExtension("mlmodelc")
    }
    
    func getZipFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("s4tf_updatable_model").appendingPathExtension("zip")
    }
    
    func getModelFileAsData() -> Data? {
        let updatableModelURL = getModelURL()
        if FileManager.default.fileExists(atPath: updatableModelURL.path){
            do {
                let zipFilePath = try Zip.quickZipFiles([updatableModelURL], fileName: "s4tf_updatable_model")
                print("zipFilePath:",zipFilePath)
                let data = try Data(contentsOf: zipFilePath)
                return data
            } catch (let error){
                print(error)
                return nil
            }
        }
        return nil
    }
    
    // POST request to backup the model
    func backupModel(completion: (() -> ())?) {
        activityIndicatorVisibility.value = true
        
        guard let modelIdEscaped = modelId.encodeURIComponent() else {
            showErrorToast()
            return
        }
        
        let endpoint = AppAPI.backupModel(id: modelIdEscaped)
        
        guard let modelFileData: Data = getModelFileAsData() else {
            showErrorToast()
            return
        }
        
        let params = HTTPParams(
            httpBody: modelFileData,
            cachePolicy: nil,
            timeoutInterval: nil,
            headerValues: nil
        )

        networkService.requestEndpoint(endpoint, params: params) { [weak self] (result) in
            guard let self = self else { return }
            
            print("7777777 1111")
            
            switch result {
            case .done(let responceStatusCode):
                print("7777777 2222")
                let statusCodeStr = String.init(data: responceStatusCode, encoding: String.Encoding.utf8)
                let statusCode = Int.init(statusCodeStr ?? "")
                if statusCode == 201 {
                    if completion != nil {
                        completion!()
                    } else {
                        self.activityIndicatorVisibility.value = false
                        self.onActionCompleted.trigger(nil)
                    }
                } else {
                    self.showErrorToast()
                }
            case .error(let error):
                print("7777777 3333")
                if error != nil {
                    self.showErrorToast(error!.localizedDescription)
                } else {
                    self.showErrorToast()
                }
            }
        }
    }
    
    // GET request to restore the model
    func restoreModel(modelId: String) {
        if modelId.isEmpty { return }
        
        activityIndicatorVisibility.value = true
        
        guard let modelIdEscaped = modelId.encodeURIComponent() else {
            showErrorToast()
            return
        }
        print("modelIdEscaped:",modelIdEscaped)
        
        let endpoint = AppAPI.restoreModel(id: modelIdEscaped)
        
        networkService.requestEndpoint(endpoint) { [weak self] (result) in
            guard let self = self else { return }
                
            switch result {
            case .done(let modelData):
                if !modelData.isEmpty {
                    let zipFileURL = self.getZipFileURL()
                    do {
                        // Write zip file to Documents directory
                        try modelData.write(to: zipFileURL, options: .atomic)
                        // Unzip model file to Documents directory
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        try Zip.unzipFile(zipFileURL, destination: documentsURL, overwrite: true, password: nil, progress: { (progress) -> () in })
                        // Remove zip file from Documents directory
                        try FileManager.default.removeItem(atPath: zipFileURL.path)
                        
                        self.activityIndicatorVisibility.value = false
                        self.onActionCompleted.trigger(nil)
                    } catch {
                        self.showErrorToast()
                    }
                } else {
                    self.showErrorToast()
                }
            case .error(let error):
                if error != nil {
                    self.showErrorToast(error!.localizedDescription)
                } else {
                    self.showErrorToast()
                }
            }
        }
    }
}
