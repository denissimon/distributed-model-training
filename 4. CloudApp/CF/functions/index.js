// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to access Cloud Storage.
const admin = require('firebase-admin');
var serviceAccount = require("./distributed-model-training-firebase-adminsdk-xaehb-b179e21109.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "gs://distributed-model-training.appspot.com",
  //databaseURL: "https://distributed-model-training.firebaseio.com"
});

const backendApiKey = '8ca557bca17ab957b6184f458af1e48';

const zipFileName = 's4tf_updatable_model.zip'

// backupModel
exports.backupModel = functions.https.onRequest(async (req, res) => {
  
  const apiKey = req.query.apiKey;
  const modelId = req.query.modelId;

  if ((apiKey != backendApiKey) || (!req.isPost)) {
    res.status(401).send('401');
  } else {
  	// Create a root reference
    var storageRef = firebase.storage().ref();
  	// Create a reference to a file
    var fileRef = storageRef.child(modelId + '/' + zipFileName);

    // Create the file metadata
	var metadata = {
	  contentType: 'application/zip'
	};

	var fileData = req.body.fileData

    fileRef.put(fileData, metadata).then(function(snapshot) {
	  res.status(200).send('200');
	}, function(error) {
	  res.status(200).send('400');
	});
  }
});

// restoreModel
exports.restoreModel = functions.https.onRequest(async (req, res) => {
  const apiKey = req.query.apiKey;
  const modelId = req.query.modelId;

  if ((apiKey != backendApiKey) || (!req.isGet)) {
    res.status(401).send('401');
  } else {
  	const storage = admin.storage().bucket();
  	var storageRef = storage.ref(modelId + '/' + zipFileName);

  	storageRef.getDownloadURL().then(function(url) {
	  // `url` is the download URL for a file 

	  // This can be downloaded directly:
	  var xhr = new XMLHttpRequest();
	  xhr.responseType = 'blob';
	  xhr.onload = function(event) {
	    var blob = xhr.response;
	  };
	  xhr.open('GET', url);
	  xhr.send();
	}).catch(function(error) {
	  res.status(404).send('404');
	});
  }
});

// changeModelId
exports.changeModelId = functions.https.onRequest(async (req, res) => {
  const apiKey = req.query.apiKey;
  const oldId = req.query.oldId;
  const newId = req.query.newId;

  if ((apiKey != backendApiKey) || (!req.isPut)) {
    res.status(401).send('401');
  } else {
  	const storage = admin.storage().bucket();

  	const srcFilename = oldId + '/' + zipFileName;
	const destFilename = newId + '/' + zipFileName;

  	var storageRef1 = storage.ref(srcFilename);
  	var storageRef2 = storage.ref(destFilename);
    
    storageRef1.getDownloadURL().then(function(url1) {
	  storageRef2.getDownloadURL().then(function(url2) {
	    res.status(403).send('403');
	  }).catch(function(error) {
	  	async function moveFile() {
		  // Moves the file within the bucket
		  await storage.file(srcFilename).move(destFilename);
		}
		try {
		  moveFile();
		  res.status(200).send('200');
		} catch (error) {
		  res.status(400).send('400');
		};
	  });
	}).catch(function(error) {
	  res.status(404).send('404');
	});
  }
});

