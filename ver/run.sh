#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh


set -e # exit on error

data=data
nj=7
mfccdir=mfcc
stage=1
stop_stage=6


if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
	echo "=== Extract MFCC & Compute VAD ==="
	for x in train test; do
		utils/utt2spk_to_spk2utt.pl data/$x/utt2spk > data/$x/spk2utt
		steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj data/$x exp/make_mfcc/$x $mfccdir
		sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" data/$x exp/make_mfcc/$x $mfccdir
  		utils/fix_data_dir.sh data/$x
	done
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
	echo "== Train UBM =="
	# train diag ubm
	sid/train_diag_ubm.sh --nj $nj --cmd "$train_cmd" \
		data/train 1024 exp/diag_ubm_1024

	#train full ubm
	sid/train_full_ubm.sh --nj $nj --cmd "$train_cmd" data/train \
		exp/diag_ubm_1024 exp/full_ubm_1024
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
	echo "== Train and Extract ivectors =="
	#train ivector
	sid/train_ivector_extractor.sh --cmd "$train_cmd" --nj 1\
		--num-iters 5 exp/full_ubm_1024/final.ubm data/train exp/extractor_1024

	#extract ivector
	sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
		exp/extractor_1024 data/train exp/ivector_train_1024

 	echo " "
	echo "Finished training and extracting ivectors.."	
	echo "== Training PLDA =="
	#train plda
	$train_cmd exp/ivector_train_1024/log/plda.log \
		ivector-compute-plda ark:data/train/spk2utt \
  	'ark:ivector-normalize-length scp:exp/ivector_train_1024/ivector.scp  ark:- |' \
		exp/ivector_train_1024/plda
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
	#split the test to enroll and eval
	mkdir -p data/test/enroll data/test/eval
	cp data/test/{spk2utt,feats.scp,vad.scp} data/test/enroll
	cp data/test/{spk2utt,feats.scp,vad.scp} data/test/eval
	local/split_data_enroll_eval.py data/test/utt2spk  data/test/enroll/utt2spk  data/test/eval/utt2spk

	trials=data/test/speaker_ver.lst

	local/produce_trials.py data/test/eval/utt2spk $trials
	utils/fix_data_dir.sh data/test/enroll
	utils/fix_data_dir.sh data/test/eval

	fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
	#extract enroll ivector
	sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
		  exp/extractor_1024 data/test/enroll  exp/ivector_enroll_1024
	#extract eval ivector
	sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
		  exp/extractor_1024 data/test/eval  exp/ivector_eval_1024

fi

if [ ${stage} -le 6 ] && [ ${stop_stage} -ge 6 ]; then

	#compute plda score
	$train_cmd exp/ivector_eval_1024/log/plda_score.log \
		ivector-plda-scoring --num-utts=ark:exp/ivector_enroll_1024/num_utts.ark \
  		exp/ivector_train_1024/plda \
  		ark:exp/ivector_enroll_1024/spk_ivector.ark \
  		"ark:ivector-normalize-length scp:exp/ivector_eval_1024/ivector.scp ark:- |" \
  		"cat '$trials' | awk '{print \\\$2, \\\$1}' |" exp/trials_out

	#compute eer
	awk '{print $3}' exp/trials_out | paste - $trials | awk '{print $1, $4}' | compute-eer -
	exit 0
fi
