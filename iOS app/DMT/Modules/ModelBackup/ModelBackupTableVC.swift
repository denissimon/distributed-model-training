//
//  ModelBackupTableVC.swift
//  DMT
//
//  Created by Denis Simon on 20.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import UIKit
import Toast_Swift

class ModelBackupTableVC: UITableViewController {
    
    @IBOutlet weak var backupSwitchCell: UITableViewCell!
    @IBOutlet weak var modelIdCell: UITableViewCell!
    @IBOutlet weak var changeModelIdCell: UITableViewCell!
    @IBOutlet weak var backupModelCell: UITableViewCell!
    @IBOutlet weak var restoreModelCell: UITableViewCell!
    
    @IBOutlet weak var backupSwitch: UISwitch!
    @IBOutlet weak var modelIdLabel: UILabel!
    
    @IBOutlet weak var changeModelIdButton: UIButton!
    @IBOutlet weak var backupButton: UIButton!
    @IBOutlet weak var restoreButton: UIButton!
    
    let viewModel = ModelBackupViewModel()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        subscribeOnEvents()
    }
    
    deinit {
        viewModel.modelBackup.networkService.cancelTask()
    }
    
    func setup() {
        if let modelBackupKey = LocalDBService.get(forKey: AppConstants.UserDefaults.modelBackupKey) {
            if modelBackupKey == "On" {
                backupSwitch.isOn = true
            } else {
                backupSwitch.isOn = false
            }
        }
        
        modelIdLabel.text = viewModel.modelBackup.modelId
    }
    
    func deselectAllRows() {
        self.tableView.deselectRow(at: IndexPath(row: 2, section: 0), animated: true)
        self.tableView.deselectRow(at: IndexPath(row: 3, section: 0), animated: true)
        self.tableView.deselectRow(at: IndexPath(row: 4, section: 0), animated: true)
    }
    
    func subscribeOnEvents() {
        // Delegates
        viewModel.modelBackup.onActionCompleted.addSubscriber(target: self, handler: { (self, _) in
            DispatchQueue.main.async {
                self.deselectAllRows()
            }
        })
        viewModel.modelBackup.showAlert.addSubscriber(target: self, handler: { (self, text) in
            DispatchQueue.main.async {
                Helpers.showAlert(title: text, message: "", vc: self)
            }
        })
        
        // Bindings
        viewModel.modelBackup.activityIndicatorVisibility.didChanged.addSubscriber(target: self, handler: { (self, value) in
            DispatchQueue.main.async {
                if value.new {
                    self.view.makeToastActivity(.center)
                } else {
                    self.view.hideToastActivity()
                }
            }
        })
    }
    
    // MARK: - Actions
    
    @IBAction func onDoneTapped(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onBackupSwitchChanged(_ sender: UISwitch) {
        viewModel.onBackupSwitchChanged(sender.isOn)
    }
    
    @IBAction func onChangeModelIdButtonTapped(_ sender: UIButton) {
        changeModelId()
    }
    @IBAction func onBackupButtonTapped(_ sender: UIButton) {
        backupModel()
    }
    @IBAction func onRestoreButtonTapped(_ sender: UIButton) {
        restoreModel()
    }
    
    // MARK: - Other methods
    
    private func changeModelId() {
        if viewModel.isActionGoing { return }
        let ac = UIAlertController(title: "New Model ID", message: nil, preferredStyle: .alert)
        ac.addTextField()
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac] _ in
            if let newModelId = ac.textFields![0].text {
                self.viewModel.changeModelId(newModelId: newModelId)
                self.deselectAllRows()
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { (action) -> Void in
            self.deselectAllRows()
        })
        ac.addAction(submitAction)
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
    
    private func backupModel() {
        if viewModel.isActionGoing { return }
        viewModel.backupModel()
    }
    
    private func restoreModel() {
        if viewModel.isActionGoing { return }
        let ac = UIAlertController(title: "Model ID", message: nil, preferredStyle: .alert)
        ac.addTextField()
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac] _ in
            if let modelId = ac.textFields![0].text {
                self.viewModel.restoreModel(modelId: modelId)
                self.deselectAllRows()
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { (action) -> Void in
            self.deselectAllRows()
        })
        ac.addAction(submitAction)
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
}

// MARK: - Table view data source

extension ModelBackupTableVC {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return backupSwitchCell
        } else if indexPath.row == 1 {
            return modelIdCell
        } else if indexPath.row == 2 {
            return changeModelIdCell
        } else if indexPath.row == 3 {
            return backupModelCell
        } else if indexPath.row == 4 {
            return restoreModelCell
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 2 {
            changeModelId()
        } else if indexPath.row == 3 {
            backupModel()
        } else if indexPath.row == 4 {
            restoreModel()
        }
    }
}
