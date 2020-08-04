# distributed-model-training

This project is determined to show an approach to implementing distributed training of machine learning models on mobile devices.

`Swift for TensorFlow` and `Google Colab` are used for creating updatable pre-trained ML model on shared/proxy data. Pre-trained model is delivered to the devices with new versions of the app. `Core ML 3` is used for on-device inferencing and re-training on user data, so they do not leave the device. `Transfer learning` and `model personalization` concepts are also used.

The implementation process is structured so that only one `Swift` programming language is used at all stages of working with the model, making this approach even more convenient and reliable thanks to the common code base, reusing of pre-processing and featurization code in different parts of the distributed system.

This approach can be an alternative to `Federated Learning` because of its significant difficulties for production use at present, especially in combination with mobile devices.

<img src="Images/iOS-app-screenshot.png" alt="Screenshot of the iOS app" width="590" />
