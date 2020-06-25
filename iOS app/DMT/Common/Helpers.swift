//
//  Helpers.swift
//  DMT
//
//  Created by Denis Simon on 08/05/2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import UIKit

class Helpers {
    
    static func showAlert(title: String, message: String = "", vc: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .cancel, handler: { (action) -> Void in
        })
        alert.addAction(ok)
        vc.present(alert, animated: true, completion: nil)
    }
}
