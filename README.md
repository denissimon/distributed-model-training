# distributed-model-training

This project aims to show an approach and mechanisms for implementing distributed training of a machine learning model - server/device training for iOS and macOS.

[`Swift for TensorFlow`](https://github.com/tensorflow/swift) is used for creating a pre-trained [foundation](https://en.wikipedia.org/wiki/Foundation_model) ML model on [shared/proxy data](https://github.com/denissimon/distributed-model-training/blob/master/1.%20macOS%20app/S4TF/housing.csv). This training takes place on a server or locally on a Mac. Then `Google Colab` and `protobuf` are used for recreating (by reusing part of weights), making `updatable`, and exporting the pre-trained model in [`.mlmodel`](https://apple.github.io/coremltools/docs-guides/source/mlmodel.html) format. The updatable pre-trained model is delivered to devices with new versions of the app or by another appropriate method. [`Core ML`](https://developer.apple.com/documentation/coreml) is used for on-device retraining on user data, so they do not leave the device, ensuring a high level of privacy, and also for inference (making predictions). [`Transfer learning`](https://en.wikipedia.org/wiki/Transfer_learning), [`online learning`](https://en.wikipedia.org/wiki/Online_machine_learning) and [`model personalization`](https://developer.apple.com/documentation/coreml/model-personalization) concepts are used for this process as well.

The implementation process is structured so that only one `Swift` programming language is used at all stages of working with the model, making this approach even more convenient and reliable thanks to a single codebase, i.e., reusing of preprocessing, featurization and validation code in different parts of the distributed system.

<img src="Images/iOS-app-screenshot.png" alt="iOS app screenshot" width="680" />

In addition, saving and restoring personal ML models (as a `.mlmodel` file) was implemented. This is particularly useful when the user reinstalls the app or changes the device.

Neural network architecture:

```swift
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
```

Training parameters:

```swift
let optimizer = RMSProp(for: model, learningRate: 0.001) 
let epochCount = 500
let batchSize = 32
let numberOfBatch = Int(ceil(Double(numTrainRecords) / Double(batchSize)))
let shuffle = true
```

***

Update: originally, `Swift for TensorFlow` was used (now in archived mode), but other tools such as `TensorFlow`, `PyTorch` or `MLX` can also be used instead. In this case, more testing will be required, since the pre-trained model will have to be written in `Python`, and the code related to data processing during on-device retraining (preprocessing, featurization and validation code) will have to be written in `Swift`. The transformation of user data from the moment it is created to when it is sent to `Core ML` should be algorithmically exactly the same as in the `Python` code.

***

This approach can also be an alternative to `Federated Learning` (FL) due to the significant difficulties in [production use](https://www.tensorflow.org/federated/faq) of FL currently, especially in combination with mobile devices.

In this case, the above process of distributed training is supplemented with `partial sharing` of user training data under certain conditions, such as only a part of them are sent to the server periodically, and only in `modified`, [`pseudonymized`](https://en.wikipedia.org/wiki/Pseudonymization), [`anonymized`](https://en.wikipedia.org/wiki/Data_anonymization) (e.g., using [differential privacy](https://en.wikipedia.org/wiki/Differential_privacy) and/or [k-anonymity](https://en.wikipedia.org/wiki/K-anonymity)) or `encrypted` form (depending on how sensitive the data is and the project requirements). With that:
1. Data storage and model training on the server occur in the same modified form.
2. When an improved pre-trained model is received on the device, replacing the personal model, it is then first retrained and re-personalized on all or part of user data (unshared data only) stored in the local DB (in plain form).
3. If necessary, the data batch needs to be transformed in real time into the same modified form before being sent to `Core ML`.

The benefit of this, besides automating and speeding up data collection for the foundation model, is that both global knowledge transfer (server->devices) and on-device knowledge transfer (devices->server) occur simultaneously, ultimately resulting in cross-device knowledge transfer that will improve subsequent predictions. At the same time, as in FL, the overall high level of privacy of user data is still maintained.

It is production-ready and can be implemented using existing established tools and technologies now.
