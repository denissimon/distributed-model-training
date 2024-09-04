# distributed-model-training

This project aims to show an approach and mechanisms to implementing distributed training of a machine learning model - server/device training for iOS.

[`Swift for TensorFlow`](https://github.com/tensorflow/swift) is used for creating a pre-trained [foundation](https://en.wikipedia.org/wiki/Foundation_model) ML model on [shared/proxy data](https://github.com/denissimon/distributed-model-training/blob/master/1.%20macOS%20app/S4TF/housing.csv). This training takes place on a server or local Mac. Then `Google Colab` and `protobuf` are used for recreating (reusing the part of weights), making `updatable`, and exporting the pre-trained model in [`.mlmodel`](https://apple.github.io/coremltools/docs-guides/source/mlmodel.html) format. The updatable pre-trained model is delivered to devices with new versions of the app. [`Core ML`](https://developer.apple.com/documentation/coreml) is used for on-device retraining on user data, so they do not leave the device, ensuring a high level of privacy, and also for inference (making predictions). [`Transfer learning`](https://en.wikipedia.org/wiki/Transfer_learning), [`online learning`](https://en.wikipedia.org/wiki/Online_machine_learning) and [`model personalization`](https://developer.apple.com/documentation/coreml/model-personalization) concepts are used for this process as well.

The implementation process is structured so that only one `Swift` programming language is used at all stages of working with the model, making this approach even more convenient and reliable thanks to a single codebase, i.e. reusing of pre-processing and featurization code in different parts of the distributed system. 

This approach can be an alternative to `Federated Learning` (FL) due to the significant difficulties in [production use](https://www.tensorflow.org/federated/faq) of FL currently, especially in combination with mobile devices.

<img src="Images/iOS-app-screenshot.png" alt="iOS app screenshot" width="630" />

In addition, backup and restoration of personal ML model (as a `.mlmodel` file) is implemented. This is particularly useful when the user reinstalls the app or changes the device.

***

Update: originally, `Swift for TensorFlow` was used (now in archived mode), but other tools such as `TensorFlow`, `PyTorch` or `Turi Create` can also be used instead. In this case, more testing will be required, since the pre-trained model will have to be written in `Python`, and code related to processing user data for on-device retraining (pre-processing and featurization code) will have to be written in `Swift`. The transformation of user data from the moment it is created to when it is sent to `Core ML` should be algorithmically exactly the same as in the `Python` code.
