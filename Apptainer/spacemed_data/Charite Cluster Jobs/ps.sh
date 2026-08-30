#!/bin/bash
#SBATCH --job-name="generate slices"
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --array=0-31
#SBATCH --output=/home/kigr11/Apptainer/spacemed_data/slurm-%A_%a.out

# the stuff we are going to do

pwd
apptainer exec --bind /home/kigr11/Data/apptainer_spacemed_data:/data /home/kigr11/Apptainer/spacemed_data/spacemed26_data.sif sm_process_slice /data/3_fMRI_TR2sec_3mm_3min.nii ${SLURM_ARRAY_TASK_ID} /home/kigr11/Apptainer/spacemed_data/ps_output_${SLURM_ARRAY_TASK_ID}.png
