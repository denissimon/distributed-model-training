//
//  AppConstants.swift
//  DMT
//
//  Created by Denis Simon on 10.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation

struct AppConstants {
    
    struct AppAPI {
        static let ApiKey = "8ca557bca17ab957b6184f458af1e48"
        //static let BaseURL = "https://169.254.168.127/"
        static let BaseURL = "https://us-central1-distributed-model-training.cloudfunctions.net"
    }
    
    struct UserDefaults {
        static let finalLossOfLastTrainingKey = "finalLossOfLastTrainingKey"
        static let modelIdKey = "modelIdKey"
        static let modelBackupKey = "modelBackupKey"
        static let dataAugmentationKey = "dataAugmentationKey"
    }
    
    struct ML {
        static let epochs = 500
        static let trainPercentage: Float = 0.8
    }
}
