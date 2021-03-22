# Kaldi-based ASR for the TORGO dataset
- Simple GMM-HMM acoustic model for teaching Kaldi.
- Simple DNN-HMM acoustic model.
- Language model building scripts come from https://github.com/cristinae/ASRdys script.

### While you could just excute the run.sh script all at once it's recommended to run by stages to better understand the code and debug any errors.
#### Stage 1: Language model building
#### Stage 2: Acoustic feature extraction (MFCC)
#### Stage 3: GMM-HMM AM training
#### Stage 4: Decode and score

# Kaldi-based Speaker identification for the TORGO dataset
- Simple GMM-HMM acoustic model for teaching Kaldi.
- Simple DNN-HMM acoustic model.
- Language model building scripts come from https://github.com/cristinae/ASRdys script.

### While you could just excute the run.sh script all at once it's recommended to run by stages to better understand the code and debug any errors.
#### Stage 1: Acoustic feature extraction and voice activity detection
#### Stage 2: Train Gaussian Mixture Model - Universal Background Model (GMM-UBM)
#### Stage 3a: Train ivector extractor and extract from audio files
#### Stage 3b: Train a Probabilistic Linear Discriminant Analysis (PLDA) model
#### Stage 4: Split test data
#### Stage 5: Extract ivectors from test data
#### Stage 6: Compute PLDA score (Equal Error Rate)


