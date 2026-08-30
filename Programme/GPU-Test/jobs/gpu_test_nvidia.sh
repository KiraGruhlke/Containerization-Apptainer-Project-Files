#!/bin/bash
#SBATCH --job-name="torch gpu test"
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:10:00

# the stuff we are going to do
pwd
source /etc/profile.d/conda.sh
conda activate torch_test
python /home/kigr11/GPU-Test/src/gpu_test.py -o matmul_result_nvidia.pt
