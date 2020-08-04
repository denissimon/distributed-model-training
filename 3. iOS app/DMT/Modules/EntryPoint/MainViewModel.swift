//
//  MainViewModel.swift
//  DMT
//
//  Created by Denis Simon on 10.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation
import SwiftEvents

class MainViewModel {
    
    let housingModel = HousingModel()
    
    var networkService: NetworkService
    
    var logsData = [String]() {
        didSet {
            onLogsDataUpdated.trigger(nil)
        }
    }
    
    var inferencingData: InferencingItem!
    
    // A number of completed training sessions
    var trainingsCount = Int()
    
    /* By default, traing/test proportion is:
    80% (405 samples) for Train, and 20% (101 samples) for Test datasets */
    var trainPercentage = AppConstants.ML.trainPercentage
    
    // Event-based delegates
    let onInferenceDone = Event<Bool?>()
    let onLogsDataUpdated = Event<Bool?>()
    let onDataAugmentationSettingChanged = Event<String>()
    // Event-based bindings
    let isTrainingGoingOn = Observable<Bool>(false)
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        subscribeOnEvents()
        housingModel.prepareData(trainPercentage: trainPercentage)
        housingModel.copyUpdatableModelFromBundleToDataContainer()
    }
    
    func subscribeOnEvents() {
        housingModel.onLogItemAppear.addSubscriber(target: self, handler: { (self, item) in
            self.logsData.append(item)
        })
    }
    
    func setSampleNumber(_ sampleNumber: Int) {
        let expectedValue = String(format: "%.2f", housingModel.data.yTest[sampleNumber-1][0])
        let preTrainedPrediction = String(format: "%.2f", housingModel.inference(model: housingModel.defaultModel!, testSample: sampleNumber-1))
        let reTrainedPrediction = String(format: "%.2f", housingModel.inference(model: housingModel.updatableModel!, testSample: sampleNumber-1))
        inferencingData = InferencingItem(sampleNumber: sampleNumber, expectedValue: expectedValue, preTrainedPrediction: preTrainedPrediction, reTrainedPrediction: reTrainedPrediction)
        onInferenceDone.trigger(nil)
    }
    
    func onTrainButton() {
        print("CoreML Start Training")
        isTrainingGoingOn.value = true
        housingModel.train() {
            print("Metrics:")
            self.housingModel.calculateMetrics()
            self.trainingsCount += 1
            self.isTrainingGoingOn.value = false
        }
    }
    
    func getTrainTestProportions() -> String {
        return "Train / Test: \(Int(trainPercentage*100))%(\(housingModel.data.numTrainRecords!)) / \(Int(100-(trainPercentage*100)))%(\(housingModel.data.numTestRecords!))"
    }
    
    func saveDataAugmentationSettingToLocalDB() {
        if let value = LocalDBService.get(forKey: AppConstants.UserDefaults.dataAugmentationKey) {
            if value == "On" {
                let newValue = "Off"
                LocalDBService.set(value: newValue, forKey: AppConstants.UserDefaults.dataAugmentationKey)
                onDataAugmentationSettingChanged.trigger(newValue)
            } else {
                let newValue = "On"
                LocalDBService.set(value: newValue, forKey: AppConstants.UserDefaults.dataAugmentationKey)
                onDataAugmentationSettingChanged.trigger(newValue)
            }
        } else {
            let newValue = "On"
            LocalDBService.set(value: newValue, forKey: AppConstants.UserDefaults.dataAugmentationKey)
            onDataAugmentationSettingChanged.trigger(newValue)
        }
    }
    
    func resetModel() {
        housingModel.removeModelFromDataContainer()
        let newRatio = AppConstants.ML.trainPercentage
        trainPercentage = newRatio
        housingModel.randomizeData(trainPercentage: newRatio)
        housingModel.copyUpdatableModelFromBundleToDataContainer()
    }
}

