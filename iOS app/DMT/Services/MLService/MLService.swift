//
//  MLService.swift
//  DMT
//
//  Created by Denis Simon on 09.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation
import CoreML
import SwiftEvents

public class HousingData {
    
    public var trainPercentage: Float!
    public var numRecords: Int!
    public var numColumns: Int!
    public var numCategoricalFeatures: Int!
    public var numNumericalFeatures: Int!
    public var numLabels: Int!
    public var numTrainRecords: Int!
    public var numTestRecords: Int!
    
    public var allCategoriesValues: [[Int32]]!
    public var mean: [Float]!
    public var std: [Float]!
    
    public var xNumericalTrain: [[Float]]!
    public var xCategoricalTrain: [[Int32]]!
    public var yTrain: [[Float]]!

    public var xNumericalTest: [[Float]]!
    public var xCategoricalTest: [[Int32]]!
    public var yTest: [[Float]]!
    
    static func matrixTranspose<T>(_ matrix: [[T]]) -> [[T]] {
        if matrix.isEmpty { return matrix }
        var result = [[T]]()
        for index in 0..<matrix.first!.count {
            result.append(matrix.map{$0[index]})
        }
        return result
    }
    
    func prepare(trainPercentage:Float = AppConstants.ML.trainPercentage) {
        // Load data
        let filePath = Bundle.main.url(forResource: "housing", withExtension: "csv")
        let data = try! String(contentsOf: filePath!, encoding: String.Encoding.utf8)
        
        // Convert CSV
        let dataRecords: [[Float]] = data.split(separator: "\n").map{ String($0).split(separator: " ").compactMap{ Float(String($0)) } }
        
        // Data ingestion
        let numRecords = dataRecords.count
        let numColumns = dataRecords[0].count
        
        // Data randomization
        var index = Set<Int>()
        while index.count < numRecords {
            index.insert(Int.random(in: 0..<numRecords))
        }
        let randomDataRecords = index.map{ dataRecords[$0] }
        let dataFeatures = randomDataRecords.map{ Array($0[0..<numColumns-1]) }
        let dataLabels = randomDataRecords.map{ Array($0[(numColumns-1)...]) }
        
        // Split numerical / categorical features
        let categoricalColumns = [3, 8]
        let numericalColumns = [0, 1, 2, 4, 5, 6, 7, 9, 10, 11, 12]
        let numCategoricalFeatures = categoricalColumns.count
        let numNumericalFeatures = numericalColumns.count
        let numLabels = 1
        assert(numColumns == numCategoricalFeatures + numNumericalFeatures + numLabels)
        
        // Get categorical features
        let allCategoriesValues = dataFeatures.map{ row in categoricalColumns.map{ Int32(row[$0]) } }
                                        .reduce(into: Array(repeating: [Int32](), count: 2)){ total, value in
                                            total[0].append(value[0])
                                            total[1].append(value[1]) }
                                        .map{ Set($0).sorted() }
        let categoricalFeatures = dataFeatures.map{ row in categoricalColumns.map{ Int32(row[$0]) } }
        
        // Get numerical features
        let numericalFeatures = dataFeatures.map{ row in numericalColumns.map{ row[$0] } }
        
        // Categorize categorical features
        var categoricalValues = Array(repeating: Set<Int32>(), count: 2)

        for record in categoricalFeatures {
            categoricalValues[0].insert(record[0])
            categoricalValues[1].insert(record[1])
        }

        let sortedCategoricalValues = [categoricalValues[0].sorted(), categoricalValues[1].sorted()]

        let ordinalCategoricalFeatures = categoricalFeatures.map{ [Int32(sortedCategoricalValues[0].firstIndex(of:$0[0])!),
                                                                   Int32(sortedCategoricalValues[1].firstIndex(of:$0[1])!)] }
        
        // Split data into train and test datasets
        let numTrainRecords = Int(ceil(Float(numRecords) * trainPercentage))
        let numTestRecords = numRecords - numTrainRecords
        let xCategoricalAllTrain = HousingData.matrixTranspose(Array(ordinalCategoricalFeatures[0..<numTrainRecords]))
        let xCategoricalAllTest = HousingData.matrixTranspose(Array(ordinalCategoricalFeatures[numTrainRecords...]))
        let xNumericalAllTrain = Array(numericalFeatures[0..<numTrainRecords])
        let xNumericalAllTest = Array(numericalFeatures[numTrainRecords...])
        let yAllTrain = Array(dataLabels[0..<numTrainRecords])
        let yAllTest = Array(dataLabels[numTrainRecords...])
        
        // Normalize numerical features
        var xTrainNormalized = xNumericalAllTrain
        var xTestNormalized = xNumericalAllTest
        
        var mean = Array(repeating: Float(0), count: numNumericalFeatures)
        for r in xTrainNormalized {
            for c in 0..<mean.count {
                mean[c] = mean[c] + r[c]
            }
        }
        for c in 0..<mean.count {
            mean[c] = mean[c] / Float(numTrainRecords)
        }

        var std = Array(repeating: Float(0), count: numNumericalFeatures)
        for r in xTrainNormalized {
            for c in 0..<mean.count {
                std[c] = std[c] + pow(r[c] - mean[c], 2.0)
            }
        }
        for c in 0..<mean.count {
            std[c] = std[c] / Float(numTrainRecords - 1)
        }

        for r in 0..<xTrainNormalized.count {
            for c in 0..<numNumericalFeatures {
                xTrainNormalized[r][c] = (xTrainNormalized[r][c] - mean[c]) / std[c]
            }
        }

        for r in 0..<xTestNormalized.count {
            for c in 0..<numNumericalFeatures {
                xTestNormalized[r][c] = (xTestNormalized[r][c] - mean[c]) / std[c]
            }
        }
        
        // Initialize class properties
        self.trainPercentage = trainPercentage
        self.numRecords = numRecords
        self.numColumns = numColumns
        self.numCategoricalFeatures = numCategoricalFeatures
        self.numNumericalFeatures = numNumericalFeatures
        self.numLabels = numLabels
        self.numTrainRecords = numTrainRecords
        self.numTestRecords = numTestRecords
        self.allCategoriesValues = allCategoriesValues
        self.mean = mean
        self.std = std

        self.xNumericalTrain = xTrainNormalized
        self.xCategoricalTrain = xCategoricalAllTrain
        self.yTrain = yAllTrain
        //print("xNumericalTrain:",xNumericalTrain)
        //print("xCategoricalTrain:",xCategoricalTrain)
        //print("yTrain:",yTrain)
        
        self.xNumericalTest = xTestNormalized
        self.xCategoricalTest = xCategoricalAllTest
        self.yTest = yAllTest
        //print("xNumericalTest:",xNumericalTest)
        //print("xCategoricalTest:",xCategoricalTest)
        //print("yTest:",yTest)
    }
}

@available(OSX 10.15, *)
public class HousingModel {
    
    let numericalInput: String = "numericalInput"
    let categoricalInput1: String = "categoricalInput1"
    let categoricalInput2: String = "categoricalInput2"
    let output: String = "output"
    let output_true: String = "output_true"
    
    var data = HousingData()
    var defaultModel: MLModel? = s4tf_pre_trained_model().model // centrally pre-trained model on shared data
    var updatableModel: MLModel? = s4tf_updatable_model().model // updatable pre-trained model (recreated from the centrally pre-trained model using Transfer Learning), ready for on-device trainings on user data
    
    // A permanent location of the updatable model
    let updatableModelURLInDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!.appendingPathComponent("s4tf_updatable_model.mlmodelc")
    
    var totalLoss: Double = 0
    
    let modelBackup = ModelBackup.shared
    
    // Event-based delegates
    let onLogItemAppear = Event<String>()
    
    func prepareData(trainPercentage:Float = AppConstants.ML.trainPercentage) {
        data.prepare(trainPercentage: trainPercentage)
        
        onLogItemAppear.trigger("Housing data pre-processing and featurization:")
        onLogItemAppear.trigger("Convert houding.csv")
        onLogItemAppear.trigger("Data ingestion")
        onLogItemAppear.trigger("Data randomization")
        onLogItemAppear.trigger("Split numerical / categorical features")
        onLogItemAppear.trigger("Get categorical features")
        onLogItemAppear.trigger("Get numerical features")
        onLogItemAppear.trigger("Categorize categorical features")
        onLogItemAppear.trigger("Split data into train and test datasets")
        onLogItemAppear.trigger("Normalize numerical features")
    }
    
    func copyUpdatableModelFromBundleToDataContainer() {
        onLogItemAppear.trigger("")
        onLogItemAppear.trigger("Housing model:")
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let destURL = documentsURL!.appendingPathComponent("s4tf_updatable_model").appendingPathExtension("mlmodelc")
        guard let sourceURL = Bundle.main.url(forResource: "s4tf_updatable_model", withExtension: "mlmodelc")
            else {
                onLogItemAppear.trigger("Pre-trained ML model was not found in Bundle")
                return
        }
        
        print("copyUpdatableModelFromBundleToDataContainer: sourceURL:",sourceURL,"destURL:",destURL)
        
        if !FileManager.default.fileExists(atPath: destURL.path) {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                onLogItemAppear.trigger("Pre-trained ML model was moved from Bundle to Data Container")
            } catch {
                onLogItemAppear.trigger("Unable to copy pre-trained ML model from Bundle to Data Container")
            }
        } else {
            onLogItemAppear.trigger("Found existing ML model in Data Container")
        }
        
        updatableModel = try! MLModel(contentsOf: destURL)
    }
    
    func randomizeData(trainPercentage: Float = AppConstants.ML.trainPercentage) {
        onLogItemAppear.trigger("")
        onLogItemAppear.trigger("Randomize data (trainPercentage = \(trainPercentage))")
        prepareData(trainPercentage: trainPercentage)
    }
    
    func removeModelFromDataContainer() {
        onLogItemAppear.trigger("")
        onLogItemAppear.trigger("Housing model:")
        onLogItemAppear.trigger("ML model was removed from Data Container")
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
        let destinationPath = documentsPath.appendingPathComponent("s4tf_updatable_model.mlmodelc")
        do {
            try FileManager.default.removeItem(atPath: destinationPath)
            print("Model removed successfully")
        } catch let error as NSError {
            print("Model removing error",error.debugDescription)
        }
    }
    
    public func inference(model: MLModel, testSample: Int) -> Float {
        guard testSample >= 0 && testSample < data.numTestRecords else { return -1 }
        
        let xNumerical: [Float] = data.xNumericalTest[testSample]
        let xCategorical1: Float = Float(data.xCategoricalTest[0][testSample])
        let xCategorical2: Float = Float(data.xCategoricalTest[1][testSample])
        
        return inference(model: model, xNumerical: xNumerical, xCategorical1: xCategorical1, xCategorical2: xCategorical2)
    }
    
    public func inference(model: MLModel, xNumerical: [Float], xCategorical1: Float, xCategorical2: Float) -> Float {
        let numericalInputMultiArr = try! MLMultiArray(shape: [NSNumber(value: data.numNumericalFeatures)], dataType: .float32)
        let categoricalInput1MultiArr = try! MLMultiArray(shape: [NSNumber(value: 1)], dataType: .float32)
        let categoricalInput2MultiArr = try! MLMultiArray(shape: [NSNumber(value: 1)], dataType: .float32)
        
        for c in 0..<data.numNumericalFeatures {
            numericalInputMultiArr[c] = NSNumber(value: xNumerical[c])
        }

        categoricalInput1MultiArr[0] = NSNumber(value: xCategorical1)
        categoricalInput2MultiArr[0] = NSNumber(value: xCategorical2)

        let numericalInputValue = MLFeatureValue(multiArray: numericalInputMultiArr)
        let categorical1InputValue = MLFeatureValue(multiArray: categoricalInput1MultiArr)
        let categorical2InputValue = MLFeatureValue(multiArray: categoricalInput2MultiArr)

        let dataPointFeatures: [String: MLFeatureValue] = [numericalInput: numericalInputValue,
                                                           categoricalInput1: categorical1InputValue,
                                                           categoricalInput2: categorical2InputValue]

        let provider = try! MLDictionaryFeatureProvider(dictionary: dataPointFeatures)
        
        let prediction = try! model.prediction(from: provider)

        return Float(prediction.featureValue(for: output)!.multiArrayValue![0].floatValue)
    }
    
    func prepareTrainingBatch() -> MLBatchProvider {
        var featureProviders = [MLFeatureProvider]()
        
        for r in 0..<data.numTrainRecords {
            let numericalInputMultiArr = try! MLMultiArray(shape: [NSNumber(value: data.numNumericalFeatures)], dataType: .float32)
            let categoricalInput1MultiArr = try! MLMultiArray(shape: [NSNumber(value: 1)], dataType: .float32)
            let categoricalInput2MultiArr = try! MLMultiArray(shape: [NSNumber(value: 1)], dataType: .float32)
            let outputMultiArr = try! MLMultiArray(shape: [NSNumber(value: data.numLabels)], dataType: .float32)

            for c in 0..<data.numNumericalFeatures {
                numericalInputMultiArr[c] = NSNumber(value: data.xNumericalTrain[r][c])
            }

            categoricalInput1MultiArr[0] = NSNumber(value: data.xCategoricalTrain[0][r])
            categoricalInput2MultiArr[0] = NSNumber(value: data.xCategoricalTrain[1][r])
            outputMultiArr[0] = NSNumber(value: data.yTrain[r][0])

            let numericalInputValue = MLFeatureValue(multiArray: numericalInputMultiArr)
            let categorical1InputValue = MLFeatureValue(multiArray: categoricalInput1MultiArr)
            let categorical2InputValue = MLFeatureValue(multiArray: categoricalInput2MultiArr)
            let outputValue = MLFeatureValue(multiArray: outputMultiArr)

            let dataPointFeatures: [String: MLFeatureValue] = [numericalInput: numericalInputValue, categoricalInput1: categorical1InputValue, categoricalInput2: categorical2InputValue, output_true: outputValue]

            if let provider = try? MLDictionaryFeatureProvider(dictionary: dataPointFeatures) {
                featureProviders.append(provider)
            }
            
            if LocalDBService.get(forKey: AppConstants.UserDefaults.dataAugmentationKey) == "On" {
                // Custom code on data augmentation goes here, depending on the type of used ML model (classification / regression) and the type of data (text / image / video / audio / etc.). As a result, a new input is added "on the fly" to featureProviders
            }
        }
        
        onLogItemAppear.trigger("Prepare training batch")
        
        return MLArrayBatchProvider(array: featureProviders)
    }

    public func train(handler: @escaping () -> ()) {
        self.onLogItemAppear.trigger("")
        self.onLogItemAppear.trigger("Training starting:")
        
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        configuration.parameters = [.epochs: AppConstants.ML.epochs]

        let progressHandler = { (context: MLUpdateContext) in
            switch context.event {
            case .trainingBegin:
                print("Training begin")
                
            case .miniBatchEnd:
                break
//                let batchIndex = context.metrics[.miniBatchIndex] as! Int
//                let batchLoss = context.metrics[.lossValue] as! Double
//                print("Mini batch \(batchIndex), loss: \(batchLoss)")

            case .epochEnd:
                let epochIndex = context.metrics[.epochIndex] as! Int
                let trainLoss = context.metrics[.lossValue] as! Double
                print("Epoch \(epochIndex) end with loss \(trainLoss)")
                if epochIndex == 0
                    || epochIndex % 10 == 0
                    || epochIndex == AppConstants.ML.epochs - 1 {
                    self.onLogItemAppear.trigger("Epoch \(epochIndex) end with loss \(trainLoss)")
                }
                self.totalLoss += trainLoss
                
            default:
                print("Unknown event")
            }
        }

        let completionHandler = { (context: MLUpdateContext) in
            print("Training completed with state \(context.task.state.rawValue)")
            print("CoreML Error: \(context.task.error.debugDescription)")
            
            if context.task.state != .completed {
                print("Failed")
                self.onLogItemAppear.trigger("Training failed")
                return
            }

            let trainLoss = context.metrics[.lossValue] as! Double
            print("Final loss: \(trainLoss)")
            self.onLogItemAppear.trigger("Final loss: \(trainLoss)")
            
            LocalDBService.set(value: trainLoss, forKey: AppConstants.UserDefaults.finalLossOfLastTrainingKey)
            
            print("CoreML Training Done!")
            self.onLogItemAppear.trigger("CoreML training is done!")
            
            self.updatableModel = context.model
            try! context.model.write(to: self.updatableModelURLInDocuments)
            self.onLogItemAppear.trigger("ML model file was replaced with a new one")
            
            if LocalDBService.get(forKey: AppConstants.UserDefaults.modelBackupKey) == "On" {
                self.modelBackup.backupModel(completion: nil)
                self.onLogItemAppear.trigger("New ML model was backuped to the cloud")
            }
            
            handler()
        }

        let handlers = MLUpdateProgressHandlers(
                            forEvents: [.trainingBegin, .miniBatchEnd, .epochEnd],
                            progressHandler: progressHandler,
                            completionHandler: completionHandler)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let updatableModelURL = documentsURL!.appendingPathComponent("s4tf_updatable_model").appendingPathExtension("mlmodelc")
        
        let updateTask = try! MLUpdateTask(forModelAt: updatableModelURL,
                                           trainingData: prepareTrainingBatch(),
                                           configuration: configuration,
                                           progressHandlers: handlers)

        updateTask.resume()
    }
    
    public func calculateMetrics() {
        onLogItemAppear.trigger("")
        
        var metricsData = [MetricItem]()

        for n in 0 ..< data.numTestRecords {
            let expectedV = data.yTest[n][0]
            let observedPreTrV = inference(model: defaultModel!, testSample: n)
            let observedReTrV = inference(model: updatableModel!, testSample: n)
            metricsData.append(MetricItem(expectedV: expectedV, observedPreTrV: observedPreTrV, observedReTrV: observedReTrV))
        }
        
        print(metricsData.count)
        print(metricsData)
        onLogItemAppear.trigger("Metrics (test dataset: \(metricsData.count) samples):")
        
        // MAE
        var preTrVSum: Float = 0
        var reTrVSum: Float = 0
        for i in metricsData {
            preTrVSum += abs(i.expectedV - i.observedPreTrV)
            reTrVSum += abs(i.expectedV - i.observedReTrV)
        }
        let maeForPreTr = preTrVSum/Float(data.numTestRecords)
        let maeForReTr = reTrVSum/Float(data.numTestRecords)
    print("housingModel.data.numTestRecords:",data.numTestRecords,"preTrVSum:",preTrVSum,"reTrVSum:",reTrVSum,"maeForPreTr:",maeForPreTr,"maeForReTr:",maeForReTr)
        onLogItemAppear.trigger("MAE for pre-trained model \(maeForPreTr)")
        onLogItemAppear.trigger("MAE for re-trained model \(maeForReTr)")
        
        // RMSE
        var preTrVSum1: Float = 0
        var reTrVSum1: Float = 0
        for i in metricsData {
            preTrVSum1 += ((i.expectedV - i.observedPreTrV) * (i.expectedV - i.observedPreTrV))
            reTrVSum1 += ((i.expectedV - i.observedReTrV) * (i.expectedV - i.observedReTrV))
        }
        let rmseForPreTr = (preTrVSum1/Float(data.numTestRecords)).squareRoot()
        let rmseForReTr = (reTrVSum1/Float(data.numTestRecords)).squareRoot()
    print("housingModel.data.numTestRecords:",data.numTestRecords,"preTrVSum1:",preTrVSum1,"reTrVSum1:",reTrVSum1,"rmseForPreTr:",rmseForPreTr,"rmseForReTr:",rmseForReTr)
        onLogItemAppear.trigger("RMSE for pre-trained model \(rmseForPreTr)")
        onLogItemAppear.trigger("RMSE for re-trained model \(rmseForReTr)")
    }
}
