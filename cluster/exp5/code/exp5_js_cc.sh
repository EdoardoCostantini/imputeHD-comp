#!/bin/bash
#SBATCH -N 1
#SBATCH -p short
#SBATCH -t 00:04:59

## Description
# Project: 	imputeHD-comp
# Title: 	lisa job script for exp 5 convergence checks (single job type)
# Partitioning: short
# Author:	Edoardo Costantini
# Date:		2021-03-16

## USAGE on LISA:
##   sbatch exp5_js_cc.sh
##
## NOTES:
##	To deploy this script for actual simulation, you need to delete the -p short
##	detail and update to the correct expected execution time the -t 00:04:59 part
##	in the preamble.

## Load Modules
module load R

## Define Variables and Directories
projDir=$HOME/exp5	  	# Project directory
inDir=$projDir/code             # Source directory (for R)
ncores=`sara-get-num-cores` 	# Number of available cores
idJob=$SLURM_JOBID	  	# Master ID for single job
idGoal=exp5_cc			# Goal of simulation

## Define Output Directories
# Temporary
tmpOut="$TMPDIR"/$idJob
mkdir -p $tmpOut

# Final
outDir=$projDir/output/$idGoal\_$idJob 	# Output directory
	if [ ! -d "$outDir" ]; then
	    mkdir -p $outDir
	fi

## Allow worker nodes to find my personal R packages:
export R_LIBS=$HOME/R/x86_64-pc-linux-gnu-library/4.0/
# for R_LIBS explain: https://statistics.berkeley.edu/computing/R-packages
# this is probably overkill but keep it in the loop for safety (and maybe ask Kyle about it)

## Store the stopos pool's name in the environment variable STOPOS_POOL:
export STOPOS_POOL=pool # Stopos will use $STOPOS_POOL if no '-p' flag is present in "stopos next -p"	

## Loop Over Cores
for (( i=1; i<ncores ; i++ )) ; do
(
	## Get the next line or parameters from the stopos pool:
	stopos next

	## Did we get a line? If not, break the loop:
	if [ "$STOPOS_RC" != "OK" ]; then
	    break
	fi

	## Call the R script with the replication number from the stopos pool:
	Rscript $inDir/exp5_simScript_cc.R $STOPOS_VALUE $tmpOut/
	# script_name.R --options repetition_counter output_directory

 	## Remove the used parameter line from the stopos pool:
	stopos remove
) &
done
wait

## Compress the output directory:

 # Go to folder containing the stuff i want to zip
 cd $tmpOut/

 # Zip everything that is inside (./.)
 tar -czf "$TMPDIR"/$idJob.tar.gz ./.

## Copy output from scratch to output directory:
 cp -a "$TMPDIR"/$idJob.tar.gz $outDir/
