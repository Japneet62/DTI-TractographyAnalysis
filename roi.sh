#!/bin/bash

chmod a+x directory_ROI.sh


# -------- FIRST LEVEL SCRIPT ------------ # 

echo " ---------------- Loading modules " 
module load hpc-env/8.3		
module load FSL
module load ConnectomeWorkbench

echo " -------------- Extracting ROIs from the atlases " 
echo " -------------------------------- " 
echo " (Includes tasks only to be run once!)" 

echo " ----------- 1. Setting global variables and create the ROI directory " 
root_dir=$WORK		 														      # location var for files, ROIs, results, data & seed_target ROIs
files_dir=$WORK/files														    # location of ENA50, config file, .cnf files, scripts 
data_dir=$root_dir/pp_data/dHCP/second_release			# location var for partic data - anat, diffusion 
results_dir=$root_dir/results												# location variable for the results directory 
seed_target_ROIs=$files/seed_target_ROIs						# location variable of the seed and target rois 
ENA=$files_dir/ENA50					  									  # location variable for the ENA atlas 

ROI=$root_dir/ROI
mkdir $ROI


		echo " ---------- 2. Setting ROI directories " 
		ROIleft=$ROI/ROIleft												     	# location variable for the left ROI
		ROIright=$ROI/ROIright													  # location variable for the right ROI

    mkdir $ROIleft
    mkdir $ROIright



		echo " --------- 3. Extract left and right ROIs from standard space from ENA33 and dHCP atlases " 

		echo " 1) OFA - ENA " 
		fslmaths $ENA/ENA50_ENA_labels.nii.gz -thr 53 -uthr 53 -bin $ROIleft/OFA_left 
		fslmaths $ENA/ENA50_ENA_labels.nii.gz -thr 54 -uthr 54 -bin $ROIright/OFA_right

		echo " 2) PSTS - dHCP " 
		fslmaths $ENA/ENA50_DEM_labels.nii.gz -thr 31 -uthr 31 -bin $ROIleft/PSTS_left 
		fslmaths $ENA/ENA50_DEM_labels.nii.gz -thr 30 -uthr 30 -bin $ROIright/PSTS_right

		echo " 3) FFA - dHCP " 
		fslmaths $ENA/ENA50_DEM_labels.nii.gz -thr 27 -uthr 27 -bin $ROIleft/FFA_left
		fslmaths $ENA/ENA50_DEM_labels.nii.gz -thr 26 -uthr 26 -bin $ROIright/FFA_right

		echo " 4) V1 - ENA " 
		fslmaths $ENA/ENA50_ENA_labels.nii.gz -thr 47 -uthr 47 -bin $ROIleft/V1_left
		fslmaths $ENA/ENA50_ENA_labels.nii.gz -thr 48 -uthr 48 -bin $ROIright/V1_right



echo " --------------------------------------------------------------------------------------------------- " 
echo " --------------------------------------------------------------------------------------------------- " 
echo " ---------------------------------- ANALYSIS 1 SUCCESSFUL ------------------------------------------ " 
echo " --------------------------------------------------------------------------------------------------- " 
echo " --------------------------------------------------------------------------------------------------- " 