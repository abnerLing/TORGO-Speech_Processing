#!/bin/bash

# Abner Hernandez (abner@snu.ac.kr) Seoul National University

. ./path.sh || exit 1
. ./cmd.sh || exit 1
nj=14

thread_nj=1

# Test-time language model order
lm_order=2
# Word position dependent phones?
pos_dep_phones=true
. utils/parse_options.sh || exit 1


Leaves=800
Gauss=9000


home_dir=/home/abner/kaldi/egs/torgo
data_dir=$home_dir/data  
feat_dir=$home_dir/mfcc
exp_dir=$home_dir/exp
lang=$data_dir/lang
lang_test=$data_dir/lang_test


stage=3
stop_stage=3

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo
    echo "===== PREPARING Language DATA ====="
    echo
    # Prepare ARPA LM and vocabulary using SRILM
    local/torgo_prepare_lm.sh --order ${lm_order} || exit 1
    
    # Prepare the lexicon and various phone lists
    # Pronunciations for OOV words are obtained using a pre-trained Sequitur model
    local/torgo_prepare_dict.sh || exit 1
    echo ""
    echo "=== Preparing data/lang and data/local/lang directories ..."
    echo ""
    
    utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones \
	    data/local/dict '!SIL' data/local/lang data/lang || exit 1
    
    # Prepare G.fst and data/{train,test} directories
    local/torgo_prepare_grammar.sh "test" || exit 1

fi    

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo
    echo "===== PREPARING ACOUSTIC DATA ====="
    echo
    # Making spk2utt files
    utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
    utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

    echo
    echo "===== FEATURES EXTRACTION ====="
    echo
    # Making feats.scp files
    mfccdir=mfcc
    utils/validate_data_dir.sh data/train 
    utils/fix_data_dir.sh data/train       
    utils/validate_data_dir.sh data/test    
    utils/fix_data_dir.sh data/test     


    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
    steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir

    # Making cmvn.scp files
    steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
    steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir
fi    


if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
	steps/train_mono.sh --nj $nj --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" \
		$data_dir/train $lang $exp_dir/mono
        steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                $data_dir/train $lang $exp_dir/mono $exp_dir/mono_ali
        steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" \
                $Leaves $Gauss $data_dir/train $lang $exp_dir/mono_ali $exp_dir/tri1
        steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                $data_dir/train $lang $exp_dir/tri1 $exp_dir/tri1_ali
        steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" \
                $Leaves $Gauss $data_dir/train $lang $exp_dir/tri1_ali $exp_dir/tri2
        steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                $data_dir/train $lang $exp_dir/tri2 $exp_dir/tri2_ali
        steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" \
                $Leaves $Gauss $data_dir/train $lang $exp_dir/tri2_ali $exp_dir/tri3
        steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                $data_dir/train $lang $exp_dir/tri3 $exp_dir/tri3_ali
        steps/train_sat.sh --cmd "$train_cmd" \
                $Leaves $Gauss $data_dir/train $lang $exp_dir/tri3_ali $exp_dir/tri4
        steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
                $data_dir/train $lang $exp_dir/tri4 $exp_dir/tri4_ali	 
fi


if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then    
    # decode
    utils/mkgraph.sh $lang_test $exp_dir/tri4 $exp_dir/tri4/graph
    steps/decode_fmllr.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
            $exp_dir/tri4/graph $data_dir/test $exp_dir/tri4/decode_test
    cat exp/tri4/decode_test/scoring_kaldi/best_wer
fi 

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    echo ""
    echo "=== Neural Network models ..."
    echo "--- nnet: Deep Neural Network (dnn)"
    local/nnet/run_dnn.sh --nj 14
fi

