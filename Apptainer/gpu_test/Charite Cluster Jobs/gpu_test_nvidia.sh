#!/bin/bash
#SBATCH --job-name="torch gpu test"
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:10:00
#SBATCH --output=/home/kigr11/Apptainer/gpu_test/slurm-%j.out

pwd
apptainer exec --nv /home/kigr11/Apptainer/gpu_test/gpu_test_nvidia.sif python /opt/gpu_test/src/gpu_test.py -o /home/kigr11/Apptainer/gpu_test/matmul_result_nvidia.pt
