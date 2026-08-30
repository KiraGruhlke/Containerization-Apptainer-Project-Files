#!/bin/bash
#SBATCH --job-name="plot heart rate bind"
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --output=/home/kigr11/Apptainer/spacemed_data/slurm-%j.out

pwd
apptainer exec --bind /home/kigr11/Data/apptainer_spacemed_data:/data /home/kigr11/Apptainer/spacemed_data/spacemed26_data.sif sm_plot_heart /data/pulse_data.csv -o /home/kigr11/Apptainer/spacemed_data/results_phr_bind.png
