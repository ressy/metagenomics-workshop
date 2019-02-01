#!/usr/bin/env bash

# A quick one-shot script for running the steps in
# metagenomics-workshop-activity.md in an automated fashion.

set -x
set -e

CORES=4
SUNBEAM_BRANCH=dev

## Prelude: symlink some data sources if present for quicker testing

## Installation

cd ~
[ -e sunbeam-$SUNBEAM_BRANCH ] || \
	git clone -b $SUNBEAM_BRANCH https://github.com/sunbeam-labs/sunbeam sunbeam-$SUNBEAM_BRANCH
ls

cd sunbeam-$SUNBEAM_BRANCH
conda env list | grep '^sunbeam ' &> /dev/null || bash install.sh

grep miniconda3 ~/.bashrc || echo 'export PATH=$PATH:~/miniconda3/bin' >> ~/.bashrc
source ~/.bashrc
hash -r

source activate sunbeam

## Upload data files

which fasterq-dump > /dev/null || conda install -y -c bioconda sra-tools

cd ~
mkdir -p workshop-data
cd workshop-data
for srrnum in 310 329 353 354 381 492 498; do
	accession="SRR2145${srrnum}"
	[ -e "${accession}_1.fastq" -a -e "${accession}_2.fastq" ] || \
		fasterq-dump "$accession" -e $CORES
done

## Initialize the project

cd ~
mkdir -p workshop-project
sunbeam init workshop-project --data_fp workshop-data --force
cd workshop-project
ls

## Download reference data

cd ~
mkdir -p human
cd human
if [ ! -e chr1.fasta ]; then
	[ -e chr1.fa.gz ] || \
		wget http://hgdownload.cse.ucsc.edu/goldenPath/hg38/chromosomes/chr1.fa.gz
	[ -e chr1.fa ] || gunzip chr1.fa.gz
	mv chr1.fa chr1.fasta
fi

cd ~
[ -e minikraken_20171101_4GB_dustmasked.tgz ] || \
	wget https://ccb.jhu.edu/software/kraken/dl/minikraken_20171101_4GB_dustmasked.tgz
[ -e minikraken_20171101_4GB_dustmasked ] || \
	tar xvzf minikraken_20171101_4GB_dustmasked.tgz

cd ~
sed -i "s;^  host_fp: ''\$;  host_fp: '$HOME/human';" workshop-project/sunbeam_config.yml
sed -i "s;^  kraken_db_fp: ''\$;  kraken_db_fp: '$HOME/minikraken_20171101_4GB_dustmasked';" workshop-project/sunbeam_config.yml

## Run the pipeline

cd ~
sunbeam run --configfile workshop-project/sunbeam_config.yml --jobs $CORES || exit 1

## Generate a report

cd ~/sunbeam-$SUNBEAM_BRANCH/extensions
[ -e sbx_report ] || git clone https://github.com/sunbeam-labs/sbx_report
conda install -y --file sbx_report/requirements.txt

cd ~
sunbeam run --configfile workshop-project/sunbeam_config.yml final_report
