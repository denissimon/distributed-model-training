//
//  Result.swift
//  DMT
//
//  Created by Denis Simon on 10.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import Foundation

enum Result<T> {
    case done(T)
    case error(Swift.Error?)
}
