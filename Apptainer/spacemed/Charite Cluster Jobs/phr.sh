#!/bin/bash
#SBATCH --job-name="plot heart rate"
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --output=/home/kigr11/Apptainer/spacemed/slurm-%j.out

pwd
apptainer exec /home/kigr11/Apptainer/spacemed/spacemed26.sif sm_plot_heart /opt/spacemed/data/pulse_data.csv -o /home/kigr11/Apptainer/spacemed/results_phr.png
