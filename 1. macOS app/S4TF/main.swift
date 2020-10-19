import Foundation
import TensorFlow
 
// 1. Data Ingestion
let filePath = Bundle.main.url(forResource: "housing", withExtension: "csv") // https://archive.ics.uci.edu/ml/machine-learning-databases/housing/
let data = try! String(contentsOf: filePath!, encoding: String.Encoding.utf8)
 
let dataRecords: [[Float]] = data.split(separator: "\n").map{ String($0).split(separator: " ").compactMap{ Float(String($0)) } }
let numRecords = dataRecords.count
let numColumns = dataRecords[0].count
 
var index = Set<Int>()
 
while index.count < numRecords {
    index.insert(Int.random(in: 0..<numRecords))
}
 
let randomDataRecords = index.map{ dataRecords[$0] }
 
let dataFeatures = randomDataRecords.map{ Array($0[0..<numColumns-1]) }
let dataLabels = randomDataRecords.map{ Array($0[(numColumns-1)...]) }
 
 
// 2. Data Transformation
 
// 2.1. Split numerical categorical features
let categoricalColumns = [3, 8]
let numericalColumns = [0, 1, 2, 4, 5, 6, 7, 9, 10, 11, 12]
let numCategoricalFeatures = categoricalColumns.count
let numNumericalFeatures = numericalColumns.count
let numLabels = 1
 
assert(numColumns == numCategoricalFeatures + numNumericalFeatures + 1)
 
// 2.2. Get categorical features
let allCategoriesValues = dataFeatures.map{ row in categoricalColumns.map{ Int32(row[$0]) } }
                                .reduce(into: Array(repeating: [Int32](), count: 2)){ total, value in
                                    total[0].append(value[0])
                                    total[1].append(value[1]) }
                                .map{ Set($0).sorted() }
 
let categoricalFeatures = dataFeatures.map{ row in categoricalColumns.map{ Int32(row[$0]) } }
 
// 2.3. Get numerical features
let numericalFeatures = dataFeatures.map{ row in numericalColumns.map{ row[$0] } }
 
// 2.4. Categorize categorical features with ordinal values
 
var categoricalValues = Array(repeating: Set<Int32>(), count: 2)
 
for record in categoricalFeatures {
    categoricalValues[0].insert(record[0])
    categoricalValues[1].insert(record[1])
}
 
let sortedCategoricalValues = [categoricalValues[0].sorted(), categoricalValues[1].sorted()]
 
let ordinalCategoricalFeatures = categoricalFeatures.map{ [Int32(sortedCategoricalValues[0].firstIndex(of:$0[0])!),
                                                           Int32(sortedCategoricalValues[1].firstIndex(of:$0[1])!)] }
 
// 2.5. Split the dataset into train and test
 
let trainPercentage:Float = 0.8
let numTrainRecords = Int(ceil(Float(numRecords) * trainPercentage))
let numTestRecords = numRecords - numTrainRecords
 
func matrixTranspose<T>(_ matrix: [[T]]) -> [[T]] {
    if matrix.isEmpty {return matrix}
    var result = [[T]]()
    for index in 0..<matrix.first!.count {
        result.append(matrix.map{$0[index]})
    }
    return result
}
 
let xCategoricalAllTrain = matrixTranspose(Array(ordinalCategoricalFeatures[0..<numTrainRecords]))
let xCategoricalAllTest = matrixTranspose(Array(ordinalCategoricalFeatures[numTrainRecords...]))
let xNumericalAllTrain = Array(Array(numericalFeatures[0..<numTrainRecords]).joined())
let xNumericalAllTest = Array(Array(numericalFeatures[numTrainRecords...]).joined())
let yAllTrain = Array(Array(dataLabels[0..<numTrainRecords]).joined())
let yAllTest = Array(Array(dataLabels[numTrainRecords...]).joined())
 
let XCategoricalTrain = xCategoricalAllTrain.enumerated().map{ (offset, element) in
    Tensor<Int32>(element).reshaped(to: TensorShape([numTrainRecords, 1]))
}
let XCategoricalTest = xCategoricalAllTest.enumerated().map{ (offset, element) in
    Tensor<Int32>(element).reshaped(to: TensorShape([numTestRecords, 1]))
}
 
let XNumericalTrainDeNorm = Tensor<Float>(xNumericalAllTrain).reshaped(to: TensorShape([numTrainRecords, numNumericalFeatures]))
let XNumericalTestDeNorm = Tensor<Float>(xNumericalAllTest).reshaped(to: TensorShape([numTestRecords, numNumericalFeatures]))
let YTrain = Tensor<Float>(yAllTrain).reshaped(to: TensorShape([numTrainRecords, numLabels]))
let YTest = Tensor<Float>(yAllTest).reshaped(to: TensorShape([numTestRecords, numLabels]))
 
// 2.6. Normalize numerical features
 
let mean = XNumericalTrainDeNorm.mean(alongAxes: 0)
let std = XNumericalTrainDeNorm.standardDeviation(alongAxes: 0)
 
print(mean, std)
// => [[3.6960156, 12.074074, 10.812822, 0.5532634, 6.2802367,  67.65161, 3.8442488, 406.00247, 18.41015, 357.95383, 12.493283]]
// => [[9.024432,   23.838202,   6.8244915, 0.117221095,  0.69898415,   28.455366,   2.1505406, 166.86064,   2.2080948,    90.48931,   6.9696417]]
 
let XNumericalTrain = (XNumericalTrainDeNorm - mean)/std
let XNumericalTest = (XNumericalTestDeNorm - mean)/std
print("Training shapes \(XNumericalTrain.shape) \(XCategoricalTrain[0].shape) \(XCategoricalTrain[1].shape) \(YTrain.shape)") // [405, 11] [405, 1] [405, 1] [405, 1]
print("Testing shapes  \(XNumericalTest.shape) \(XCategoricalTest[0].shape) \(XCategoricalTest[1].shape) \(YTest.shape)") // [101, 11] [101, 1] [101, 1] [101, 1]
 
 
// 3. Model
 
struct MultiInputs<N: Differentiable, C>: Differentiable {
  var numerical: N
  
  @noDerivative
  var categorical: C
 
  @differentiable
  init(numerical: N, categorical: C) {
    self.numerical = numerical
    self.categorical = categorical
  }
}
 
struct RegressionModel: Module {
    var embedding1 = TensorFlow.Embedding<Float>(vocabularySize: 2, embeddingSize: 2)
    var embedding2 = TensorFlow.Embedding<Float>(vocabularySize: 9, embeddingSize: 5)
    var allInputConcatLayer = Dense<Float>(inputSize: (11 + 2 + 5), outputSize: 64, activation: relu)
    var hiddenLayer = Dense<Float>(inputSize: 64, outputSize: 32, activation: relu)
    var outputLayer = Dense<Float>(inputSize: 32, outputSize: 1)
    
    @differentiable
    func callAsFunction(_ input: MultiInputs<[Tensor<Float>], [Tensor<Int32>]>) -> Tensor<Float> {
        let embeddingOutput1 = embedding1(input.categorical[0])
        let embeddingOutput1Reshaped = embeddingOutput1.reshaped(to:
            TensorShape([embeddingOutput1.shape[0], embeddingOutput1.shape[2]]))
        let embeddingOutput2 = embedding2(input.categorical[1])
        let embeddingOutput2Reshaped = embeddingOutput2.reshaped(to:
            TensorShape([embeddingOutput2.shape[0], embeddingOutput2.shape[2]]))
        let allConcat = Tensor<Float>(concatenating: [input.numerical[0], embeddingOutput1Reshaped, embeddingOutput2Reshaped], alongAxis: 1)
        return allConcat.sequenced(through: allInputConcatLayer, hiddenLayer, outputLayer)
    }
}
 
var model = RegressionModel()
 
 
// 4. Training
let optimizer = RMSProp(for: model, learningRate: 0.001)
Context.local.learningPhase = .training
 
let epochCount = 500
let batchSize = 32
let numberOfBatch = Int(ceil(Double(numTrainRecords) / Double(batchSize)))
let shuffle = true
 
func mae(predictions: Tensor<Float>, truths: Tensor<Float>) -> Float {
    return abs(Tensor<Float>(predictions - truths)).mean().scalarized()
}
 
for epoch in 1...epochCount {
    var epochLoss: Float = 0
    var epochMAE: Float = 0
    var batchCount: Int = 0
    var batchArray = Array(repeating: false, count: numberOfBatch)
    for batch in 0..<numberOfBatch {
        var r = batch
        if shuffle {
            while true {
                r = Int.random(in: 0..<numberOfBatch)
                if !batchArray[r] {
                    batchArray[r] = true
                    break
                }
            }
        }
        
        let batchStart = r * batchSize
        let batchEnd = min(numTrainRecords, batchStart + batchSize)
        let (loss, grad) = model.valueWithGradient { (model: RegressionModel) -> Tensor<Float> in
            let multiInput = MultiInputs(numerical: [XNumericalTrain[batchStart..<batchEnd]],
                                         categorical: [XCategoricalTrain[0][batchStart..<batchEnd],
                                                       XCategoricalTrain[1][batchStart..<batchEnd]])
            let logits = model(multiInput)
            return meanSquaredError(predicted: logits, expected: YTrain[batchStart..<batchEnd])
        }
        optimizer.update(&model, along: grad)
        
        let multiInput = MultiInputs(numerical: [XNumericalTrain[batchStart..<batchEnd]],
                                     categorical: [XCategoricalTrain[0][batchStart..<batchEnd],
                                                   XCategoricalTrain[1][batchStart..<batchEnd]])
        let logits = model(multiInput)
        epochMAE += mae(predictions: logits, truths: YTrain[batchStart..<batchEnd])
        epochLoss += loss.scalarized()
        batchCount += 1
    }
    epochMAE /= Float(batchCount)
    epochLoss /= Float(batchCount)
 
    print("Epoch \(epoch): MSE: \(epochLoss), MAE: \(epochMAE)")
}
 
// 4.1. Test the trained model
 
Context.local.learningPhase = .inference
 
let multiInputTest = MultiInputs(numerical: [XNumericalTest],
                                 categorical: [XCategoricalTest[0],
                                               XCategoricalTest[1]])
 
let prediction = model(multiInputTest)
 
let predictionMse = meanSquaredError(predicted: prediction, expected: YTest).scalarized()/Float(numTestRecords)
let predictionMae = mae(predictions: prediction, truths: YTest)/Float(numTestRecords)
 
print("MSE: \(predictionMse), MAE: \(predictionMae)")
// => MSE: 0.18782271, MAE: 0.025332946
 
 
// 5. Export parameters of the trained model
 
print(model.embedding1.embeddings.shape, model.embedding2.embeddings.shape)
// => [2, 2] [9, 5]
 
// embedding1
print("weight:", model.embedding1.embeddings.transposed().flattened().scalars)
 
// embedding2
print("weight:", model.embedding2.embeddings.transposed().flattened().scalars)
 
// dense1
print("weight:", model.allInputConcatLayer.weight.transposed().flattened().scalars)
print("bias:", model.allInputConcatLayer.bias.flattened().scalars)
 
// dense2
print("weight:", model.hiddenLayer.weight.transposed().flattened().scalars)
print("bias:", model.hiddenLayer.bias.flattened().scalars)
 
// dense3
print("weight:", model.outputLayer.weight.transposed().flattened().scalars)
print("bias:", model.outputLayer.bias.flattened().scalars)
