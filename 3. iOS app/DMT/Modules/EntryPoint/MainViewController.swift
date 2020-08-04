//
//  MainViewController.swift
//  DMT
//
//  Created by Denis Simon on 08.05.2020.
//  Copyright © 2020 Denis Simon. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    
    var viewModel = MainViewModel(networkService: NetworkService())
    
    @IBOutlet weak var topTableView: UITableView!
    @IBOutlet weak var bottomTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        topTableView.dataSource = self
        topTableView.delegate = self
        bottomTableView.dataSource = self
        bottomTableView.delegate = self
        
        subscribeOnEvents()
        
        setup()
    }
    
    func subscribeOnEvents() {
        // Delegates
        viewModel.onInferenceDone.addSubscriber(target: self, handler: { (self, _) in
            self.topTableView.reloadData()
        })
        viewModel.onLogsDataUpdated.addSubscriber(target: self, handler: { (self, _) in
            DispatchQueue.main.async {
                self.bottomTableView.reloadData()
                self.scrollLogsToBottom()
            }
        })
        viewModel.onDataAugmentationSettingChanged.addSubscriber(target: self, handler: { (self, value) in
            Helpers.showAlert(title: "Data augmentation is \(value)", vc: self)
        })
        
        // Bindings
        viewModel.isTrainingGoingOn.didChanged.addSubscriber(target: self, handler: { (self, _) in
            DispatchQueue.main.async {
                let currentSampleNumber = self.viewModel.inferencingData.sampleNumber
                self.viewModel.setSampleNumber(currentSampleNumber)
                self.topTableView.reloadData()
            }
        })
    }
    
    func setup() {
        viewModel.setSampleNumber(1)
        scrollLogsToBottom()
    }
    
    func scrollLogsToBottom() {
        let currentLogsDataCount = viewModel.logsData.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if self.viewModel.logsData.count <= currentLogsDataCount {
                self.bottomTableView.scrollToRow(at: IndexPath(row: self.viewModel.logsData.count-1, section: 0), at: .bottom, animated: true)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc func onSliderChange(_ sender: UISlider) {
        let currentValue = sender.value
        //let row = sender.tag
        viewModel.setSampleNumber(Int(currentValue))
    }
    
    @objc func onTrainButton(_ sender: UIButton) {
        //let row = sender.tag
        sender.isEnabled = false
        viewModel.onTrainButton()
    }
    
    @IBAction func onSettingsButton(_ sender: UIButton) {
        let alert = UIAlertController(title: "Settings",
                                      message: nil,
                                      preferredStyle: UIAlertController.Style.actionSheet)
        
        let resetModelAction = UIAlertAction(title: "Reset model",
                                        style: .destructive, handler: { (alert: UIAlertAction!) in
            self.resetModel()
        })
        let changeTrainTestProportionsAction = UIAlertAction(title: viewModel.getTrainTestProportions(),
                                                        style: .default, handler: { (alert: UIAlertAction!) in
            self.showRatioSelection()
        })
        let modelBackupAction = UIAlertAction(title: "Model backup",
                                                        style: .default, handler: { (alert: UIAlertAction!) in
            self.modelBackupAction()
        })
        let dataAugmentationOnOffAction = UIAlertAction(title: "Data augmentation",
                                                        style: .default, handler: { (alert: UIAlertAction!) in
            self.saveDataAugmentationSettingToLocalDB()
        })
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel, handler: nil)
        
        if viewModel.isTrainingGoingOn.value {
            resetModelAction.isEnabled = false
            changeTrainTestProportionsAction.isEnabled = false
            modelBackupAction.isEnabled = false
            dataAugmentationOnOffAction.isEnabled = false
        }
        
        alert.addAction(resetModelAction)
        alert.addAction(changeTrainTestProportionsAction)
        alert.addAction(modelBackupAction)
        alert.addAction(dataAugmentationOnOffAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    private func resetModel() {
        viewModel.resetModel()
        setup()
    }
    
    private func showRatioSelection() {
        let alert = UIAlertController(title: "Train Ratio",
                                      message: nil,
                                      preferredStyle: UIAlertController.Style.actionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel, handler: nil)

        for i in 1..<10 {
            let newRatio = Float(Double(i)/Double(10))
            print(newRatio)
            alert.addAction(UIAlertAction(title: String(i*10)+"%",
                                          style: .default, handler: { (alert: UIAlertAction!) in
                self.viewModel.trainPercentage = newRatio
                self.viewModel.housingModel.randomizeData(trainPercentage: newRatio)
                self.topTableView.reloadData()
                self.viewModel.setSampleNumber(1)
            })
            )
        }
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    func saveDataAugmentationSettingToLocalDB() {
        viewModel.saveDataAugmentationSettingToLocalDB()
    }
    
    func modelBackupAction() {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let backupModelVC = mainStoryboard.instantiateViewController(withIdentifier: "ModelBackup") as! ModelBackupTableVC
        let backupModelNC = UINavigationController(rootViewController: backupModelVC)
        present(backupModelNC, animated: true, completion: nil)
    }
}

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    // MARK: UITableViewController delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == topTableView {
            return 2
        } else if tableView == bottomTableView {
            return 1
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = Int()
        
        if tableView == topTableView {
            if section == 0 {
                return 1
            } else {
                return 5
            }
        } else if tableView == bottomTableView {
            count = viewModel.logsData.count
        }
        
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        
        if tableView == topTableView {
            // Table view cells are reused and should be dequeued using a cell identifier.
            if indexPath.section == 0 {
                if indexPath.row == 0 {
                    let cellIdentifier = "TrainingCell"
                    let cell_ = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! TrainingCell
                    
                    // Configure the cell...
                    var trainingStatus = "Not trained yet"
                    if viewModel.isTrainingGoingOn.value {
                        trainingStatus = "Training starting"
                    } else {
                        if let finalLossOfLastTraining = LocalDBService.get(forKey: AppConstants.UserDefaults.finalLossOfLastTrainingKey) {
                            if viewModel.trainingsCount > 0 {
                                trainingStatus = "Training completed with final loss:\n" + finalLossOfLastTraining
                            } else {
                                trainingStatus = "Last training's final loss:\n" + finalLossOfLastTraining
                            }
                        }
                    }
                    
                    cell_.label.text = trainingStatus
                    cell_.trainButton.tag = indexPath.row
                    cell_.trainButton.addTarget(self, action: #selector(onTrainButton), for: .touchUpInside)
                    if viewModel.isTrainingGoingOn.value {
                        cell_.trainButton.isEnabled = false
                    } else {
                        cell_.trainButton.isEnabled = true
                    }
                    cell = cell_
                }
            } else if indexPath.section == 1 {
                if indexPath.row == 4 {
                    let cellIdentifier = "SliderCell"
                    let cell_ = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! SliderCell
                    
                    // Configure the cell...
                    cell_.slider.setValue(Float(viewModel.inferencingData.sampleNumber), animated: false)
                    cell_.slider.maximumValue = Float(viewModel.housingModel.data.numTestRecords!)
                    cell_.slider.tag = indexPath.row
                    cell_.slider.addTarget(self, action: #selector(onSliderChange(_:)), for: .valueChanged)
                    if viewModel.isTrainingGoingOn.value {
                        cell_.slider.isEnabled = false
                    } else {
                        cell_.slider.isEnabled = true
                    }
                    cell = cell_
                } else {
                    let cellIdentifier = "InferencingCell"
                    cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
                    if indexPath.row == 0 {
                        cell.textLabel?.text = "Expected:"
                        cell.detailTextLabel?.text = viewModel.inferencingData.expectedValue
                    } else if indexPath.row == 1 {
                        cell.textLabel?.text = "Pre-trained model prediction:"
                        cell.detailTextLabel?.text = viewModel.inferencingData.preTrainedPrediction
                    } else if indexPath.row == 2 {
                        cell.textLabel?.text = "Re-trained model prediction:"
                        cell.detailTextLabel?.text = viewModel.inferencingData.reTrainedPrediction
                    } else if indexPath.row == 3 {
                        cell.textLabel?.text = "Sample number:"
                        cell.detailTextLabel?.text = String(viewModel.inferencingData.sampleNumber)
                    }
                }
            }
            
        } else if tableView == bottomTableView {
        
            // Table view cells are reused and should be dequeued using a cell identifier.
            let cellIdentifier = "LogItem"
            
            cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! UITableViewCell
            
            cell.textLabel?.text = viewModel.logsData[indexPath.row]
        }
        
        return cell
    }
    
    //func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //}
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == topTableView {
            if section == 0 {
                return "Training"
            } else {
                return "Inferencing"
            }
        } else if tableView == bottomTableView {
            if section == 0 {
                return "Logs"
            }
        }
        return ""
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

