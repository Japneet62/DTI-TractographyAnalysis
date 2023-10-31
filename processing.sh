#!/bin/bash


subj_id=$1
ses_id=$2
data_dir=$3
root_dir=$4
results=$5 
ENA=$6
files_dir=$7
roileft=$8 
roiright=$9



echo " ----------- STEP viii. Setting subject specific directories to extract data from subject files " 
sub_id=sub-${subj_id}                                                            # create a new subject id variable to add sub- in front of subject id
sess_id=ses-${ses_id}                                                            # create a new session id variable add ses- in front of session id 

sub_dwi=${data_dir}/dhcp_dmri_pipeline/${sub_id}/${sess_id}/dwi                  # variable to access the dwi folder for subject 
bedpostx=${data_dir}/dhcp_dmri_pipeline/${sub_id}/${sess_id}/dwi.bedpostX # variable to access the bedpostx results folder, already done by Juan 
sub_anat=${data_dir}/dhcp_anat_pipeline/${sub_id}/${sess_id}/anat                # variable to access the anatomical files of subject

echo " ----------- Create results directories for subjects" 

cd $results                                                         # go to the folder where all the results files are saved
results_temp=${results}/${sub_id}_${sess_id}_results                # var for specific subject's results to be saved 
res_vers=$(ls -d ${sub_id}_${sess_id}_results* | wc -l)	            # = "results version" (how often the same subject has been analyzed)




echo " -----------  Results version: $res_vers" 

if (( $res_vers >= 1 )); then                             # if there is already one or more results directories of this subject

	results_dir=$results/${sub_id}_${sess_id}_results_$((res_vers + 1)) # create a second results directory with the number of the current repetition attached
	mkdir $results_dir									                                # but make sure to still check the original non-numbered directory for the intermediary files#
	
	echo " ----------- Analysis Has Been Performed $res_vers Times. Creating New Results Directory" 
	
  else

	mkdir $results_temp	
	results_dir=$results_temp

	echo " ----------- Performing Analysis For The 1st Time" 
  
  fi


 






























roi_stan2diff_L=${results_dir}/roi_stan2diff_L		   # ROIs left hem converted from standrd to subject's diffusion space 
roi_stan2diff_R=${results_dir}/roi_stan2diff_R		   # ROIs left hem converted from standrd to subject's diffusion space 

mkdir ${roi_stan2diff_L}                             # creating new folders 
mkdir ${roi_stan2diff_R}

reg=${results_dir}/reg									             # registration results for subject 
mkdir ${reg}

dtifit=${results_dir}/dtifit							      	   # DTIFIT results for subject 
mkdir ${dtifit} 

echo " ----------- STEP ix. Setting tractography and stats directories "
tract=${results_dir}/tract								      	# probtrackx2 resuts 
tract_thresh=${results_dir}/tract_thresh					# tractography results after thresholding 
tract_mul=${results_dir}/tract_mul					  		# results after multiplying the thresholded tractographies for the left and right hemispheres together 
tract_mask=${results_dir}/tract_mask             
tract_LR=${results_dir}/tract_LR		
stopmask=${results_dir}/stopmasks
stats_saver=${results}/stats_saver

mkdir ${tract}
mkdir ${tract_thresh}
mkdir ${tract_mul}
mkdir ${tract_mask} 
mkdir ${tract_LR}
mkdir ${stopmask}






















echo "-----------  STARTING ANALYSIS FOR SUBJECT ${sub_id} ${sess_id} ---------------- " 

echo " ----------- 2. BEGIN PREPROCESSING ---------------- "









echo " ---------------------- STEP 1) Skull stripping "

cd ${sub_anat}
bet2 ${sub_id}_${sess_id}_desc-restore_T2w.nii.gz ${reg}/0.4desc_restoreT2w_noskull.nii.gz -f 0.4    # use on individual structural image and adjust fractional intensity threshold
bet2 ${sub_id}_${sess_id}_desc-restore_T2w.nii.gz ${reg}/0.2desc_restoreT2w_noskull.nii.gz -f 0.2
bet2 ${sub_id}_${sess_id}_desc-restore_T2w.nii.gz ${reg}/0.1desc_restoreT2w_noskull.nii.gz -f 0.1

cd ${reg}
fslmaths 0.4desc_restoreT2w_noskull.nii.gz -add 0.2desc_restoreT2w_noskull.nii.gz -add 0.1desc_restoreT2w_noskull.nii.gz desc_restoreT2w_noskull.nii.gz	

# Save all the desc_restore_T2 files in registration folder 


echo " --------- STEP 2) b0 image extraction "
fslroi ${sub_dwi}/data.nii.gz ${reg}/b0.nii.gz 0 1         # save b0 image in registration folder 








echo " ----------- 3. STARTING REGISTRATIONS ------------- " 

cd ${reg}            # Output of these steps saved in registration folder 

echo " ---------------------- STEP i. Linear registration from individual to structural space " 
flirt -in b0.nii.gz -ref desc_restoreT2w_noskull.nii.gz -out linreg -omat diff2struct_warp.mat		


echo " ---------------------- STEP ii. Linear registration from structural to standard space "
flirt -in desc_restoreT2w_noskull.nii.gz -ref ${ENA}/ENA50_T2w.nii.gz -out linreg_str2stan -omat struc2stan_linear_warp.mat


echo " ---------------------- STEP iii. Non linear registration "
fnirt --ref=${ENA}/ENA50_T2w.nii.gz --in=desc_restoreT2w_noskull.nii.gz --iout=nonlinreg --cout=fnirted_coefs								


cd ${reg} 
echo " ------------------------ STEP iv. Reverse linreg Indiv to structural"
convert_xfm -omat "diff2struct_warp_rev.mat" -inverse diff2struct_warp.mat								


echo " ------------------------ STEP v. Reverse struc2stan_linear_warp.mat " 
convert_xfm -omat "struc2stan_linear_warp_rev.mat" -inverse struc2stan_linear_warp.mat 	


echo " ---------------------- STEP vi. Reverse non linear registration " 
invwarp --ref=desc_restoreT2w_noskull.nii.gz --warp=fnirted_coefs.nii.gz --out=fnirted_coefs_rev	













echo " ----------- 4. TRANSFORM ROIs FROM STANDARD TO DIFFUSION SPACE IN LEFT AND RIGHT HEMISPHERE ---------------  " 

    index=0
    
    cd $roileft
    for roiL in *.nii.gz; do
    
    index=$((index + 1))
      echo " ------------------  Transforming: ROI left ${roiL}"
    
    	# necessary files for applywarp:
    	# -- b0.nii.gz = individual functional image (-reference)
    	# -- linreg_rev.mat = linear warp from indiv diffusion to structural space (-postmat)
    	# -- struc2stan_linear_warp_rev.mat = linear warp from indiv struct to standard space (-premat)
    	# -- nonlinreg_warpcoef_rev = nonlinear warp from indiv struct to standard space (-warp)      
     
    
    almostroi="${roiL%.*}"               # remove file extensions
    noext_roiL="${almostroi%.*}"             # for later use in naming of applywarp output file
    
   	applywarp --ref=${reg}/b0.nii.gz --in=${roileft}/${roiL} --postmat=${reg}/diff2struct_warp_rev.mat --premat=${reg}/struc2stan_linear_warp_rev.mat --warp=${reg}/fnirted_coefs_rev.nii.gz --out=${roi_stan2diff_L}/${noext_roiL}_2diff
    
    done


 


    index=0
    
    cd $roiright
    for roiR in *.nii.gz; do
    
    index=$((index + 1))

   	echo " ------------------  Transforming: ROI right ${roiR}"

    	# necessary files for applywarp:
    	# -- b0.nii.gz = individual functional image (-reference)
    	# -- linreg_rev.mat = linear warp from indiv diffusion to structural space (-postmat)
    	# -- struc2stan_linear_warp_rev.mat = linear warp from indiv struct to standard space (-premat)
    	# -- nonlinreg_warpcoef_rev = nonlinear warp from indiv struct to standard space (-warp)

      almostroi="${roiR%.*}"               # remove file extensions
      noext_roiR="${almostroi%.*}"             # for later use in naming of applywarp output file
    

    	applywarp --ref=${reg}/b0.nii.gz --in=${roiright}/${roiR} --postmat=${reg}/diff2struct_warp_rev.mat --premat=${reg}/struc2stan_linear_warp_rev.mat --warp=${reg}/fnirted_coefs_rev.nii.gz --out=${roi_stan2diff_R}/${noext_roiR}_2diff
    
    done






echo " ----------- 5. BedpostX DONE BEFORE -------------- " 








echo " ----------- 6. PREPARE FILES FOR TRACTOGRAPHY -------------- " 


echo " ---------------------- STEP 1. Create FA image "
cd ${sub_dwi}
dtifit -k data.nii.gz -o ${dtifit}/dtifit -m nodif_brain_mask.nii.gz -r bvecs -b bvals 



echo " ---------------------- STEP ii. turn FA image into a mask and threshold for use as stop mask " 
cd ${dtifit}
fslmaths dtifit_FA.nii.gz -thr 0 -uthr 0.1 -bin ${stopmask}/FA_mask.nii.gz



echo " ---------------------- STEP iii. Convert PIAL mask from structural to diffusion space for left hemisphere " 
applywarp --ref=${reg}/b0.nii.gz --in=${sub_anat}/L_PIAL_surf2vol_stop_mask.nii.gz --postmat=${reg}/diff2struct_warp_rev.mat --out=${stopmask}/L_PIAL_stopmask	



echo " ---------------------- STEP iv. Convert PIAL mask from structural to diffusion space for right hemisphere " 
applywarp --ref=${reg}/b0.nii.gz --in=${sub_anat}/R_PIAL_surf2vol_stop_mask.nii.gz --postmat=${reg}/diff2struct_warp_rev.mat --out=${stopmask}/R_PIAL_stopmask	



echo " ----------------------  STEP v. Combine stopmasks for left and right hemisphere together "
cd ${stopmask}
fslmaths L_PIAL_stopmask.nii.gz -add R_PIAL_stopmask.nii.gz LR_PIAL_stopmask.nii.gz








echo " ---------------------- STEP vi. Create text files with list of stopmasks for each hemisphere "
echo "$stopmask/L_PIAL_stopmask.nii.gz" >> stopmask_L.txt
echo "$stopmask/R_PIAL_stopmask" >> stopmask_R.txt
echo "$stopmask/FA_mask.nii.gz" >> stopmask_L.txt
echo "$stopmask/FA_mask.nii.gz" >> stopmask_R.txt

echo "$stopmask/FA_mask.nii.gz" >> stopmask_both.txt
echo "$stopmask/LR_PIAL_stopmask.nii.gz" >> stopmask_both.txt













echo " ----------- 7. START TRACTOGRAPHY FOR SUBJECT ${sub_id} ${sess_id} ---------------"

echo " ----------------------  Starting tractography for the left hemisphere" 

cd ${files_dir}

while IFS=";"; read SEEDroi TARGETroi empty; do				# enter while loop and read the seed and target roi from the csv file

    cd ${sub_dwi}

    echo "----------------------  From ${SEEDroi}_to_${TARGETroi}"		
   
 		probtrackx2 --samples=${bedpostx}/"merged" --opd -m ${sub_dwi}/nodif_brain_mask.nii.gz -x ${roi_stan2diff_L}/${SEEDroi} -P 5000 --forcedir --dir=${tract} -o ${SEEDroi}_to_${TARGETroi}_probtract.nii.gz --waypoints=${roi_stan2diff_L}/${TARGETroi} --wtstop=${roi_stan2diff_L}/${TARGETroi} --stop=${stopmask}/stopmask_L.txt

done < ${files_dir}/SeedTargetROI_L.csv  								# .csv file with seed and target ROIs for left hemisphere



echo " ---------------------- Starting tractography for the right hemisphere "

cd ${files_dir}

while IFS=";"; read SEEDroi TARGETroi empty; do				# enter while loop and read the seed and target roi from the csv file

    cd ${sub_dwi}
    echo " ---------------------- From ${SEEDroi}_to_${TARGETroi}"
    
    probtrackx2 --samples=${bedpostx}/"merged" --opd -m ${sub_dwi}/nodif_brain_mask.nii.gz -x ${roi_stan2diff_R}/${SEEDroi} -P 5000 --forcedir --dir=${tract} -o ${SEEDroi}_to_${TARGETroi}_probtract.nii.gz --waypoints=${roi_stan2diff_R}/${TARGETroi} --wtstop=${roi_stan2diff_R}/${TARGETroi} --stop=${stopmask}/stopmask_R.txt

done < ${files_dir}/SeedTargetROI_R.csv  								# .csv file with seed and target ROIs for left hemisphere















echo " ----------- 8. STATISTICAL ANALYSIS -------------------------------------------- " 


echo " ---------------------- STEP 1. Thresholding all the files recieved from tractograhy "
# ${thr_type}_thr${thr} 
thr_type=thrp
thr=5	



cd ${files_dir} 
while IFS=';'; read SeedROI TargetROI empty; do  
		echo "---------------------- ${SeedROI} ${TargetROI} left"
		echo "---------------------- thresholding tractography of ${SeedROIL} to ${TargetROIL} ${thr_type}.${thr} for tractographies of left hemisphere"
   
		cd ${tract}
		fslmaths ${SeedROI}_to_${TargetROI}_probtract.nii.gz -$thr_type $thr ${tract_thresh}/${SeedROI}_2_${TargetROI}_${thr_type}.${thr}.nii.gz
	
done < ${files_dir}/SeedTargetROI_L.csv


cd ${files_dir} 
while IFS=';'; read SeedROI TargetROI empty; do 
  
		echo "---------------------- ${SeedROI} to ${TargetROI} right"
		echo "---------------------- thresholding tractography of ${SeedROIR} to ${TargetROIR}, ${thr_type}.${thr} for tractographies of right hemisphere"

		cd ${tract}
		fslmaths ${SeedROI}_to_${TargetROI}_probtract.nii.gz -$thr_type $thr ${tract_thresh}/${SeedROI}_2_${TargetROI}_${thr_type}.${thr}.nii.gz

done < ${files_dir}/SeedTargetROI_R.csv














echo "----------- STEP 2. Multiplying the thresholded ROI pairs " 

Ldata="left_2diff"
Rdata="right_2diff"

cd ${files_dir}

      while IFS=';'; read SeedROI TargetROI empty; do  					# loop through all the tractographies of left hem
      
          
      		cd ${tract_thresh}
         
      		echo "---------------------- multiplying tractography from ${SeedROI} to ${TargetROI} and ${TargetROI} to ${SeedROI} for left hemisphere "
      		fslmaths ${SeedROI}_${Ldata}_2_${TargetROI}_${Ldata}_${thr_type}.${thr}.nii.gz -mul ${TargetROI}_${Ldata}_2_${SeedROI}_${Ldata}_${thr_type}.${thr}.nii.gz ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}
      		
      		echo "----------- ----------- multiplying tractography from ${SeedROI} to ${TargetROI} and ${TargetROI} to ${SeedROI} for right hemisphere "
      		fslmaths ${SeedROI}_${Rdata}_2_${TargetROI}_${Rdata}_${thr_type}.${thr}.nii.gz -mul ${TargetROI}_${Rdata}_2_${SeedROI}_${Rdata}_${thr_type}.${thr}.nii.gz ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}
      
      
      done < ${files_dir}/ROI_List_single_short.csv
      
      
      
      
      
      
      
      
      
      
      

echo "----------- STEP 3. Binarising all the files in tract_mul folder - includes left & right hemispheres"

	cd ${files_dir}
	while IFS=';'; read SeedROI TargetROI empty; do  					# loop through all the tractographies of left hem
	
 
	fslmaths ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}.nii.gz -bin $tract_mask/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}.nii.gz
	fslmaths ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}.nii.gz -bin $tract_mask/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}.nii.gz
			
	done < ${files_dir}/ROI_List_single_short.csv											# end loop for left hem seed and target rois
 
 
 
 
 
 
 
 

echo "----------- STEP 4. Adding L and R hemispheres together "
  	cd ${files_dir}
  	while IFS=';'; read SeedROI TargetROI empty; do  					# loop through all the tractographies of left hem
  	

  	fslmaths ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}.nii.gz -add ${tract_mul}/${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}.nii.gz $tract_LR/LR_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_${thr_type}.${thr}.nii.gz
  			
  	done < ${files_dir}/ROI_List_single_short.csv											# end loop for left hem seed and target rois
  










echo "----------- STEP 5. Calculating Tract Statistics " 

    cd ${files_dir}
    while IFS=';'; read SeedROI TargetROI empty; do  
    
    
    		echo "---------------------- For file: ${tract_mask}/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}"
    
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_l_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -M >> $tracstats/sub-${subj_id}_Lmean.txt
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_l_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -S >> $tracstats/sub-${subj_id}_LStd.txt
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_r_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -M >> $tracstats/sub-${subj_id}_Rmean.txt
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_r_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -S >> $tracstats/sub-${subj_id}_RStd.txt
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_LR_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -M >> $tracstats/sub-${subj_id}_LRmean.txt
    		#fslstats $dtifit/dtifit_FA.nii.gz -k $results_temp/tractresults/mask_LR_sub-${subj_id}_${sSeedROI}_X_${sTargetROI}.nii.gz -S >> $tracstats/sub-${subj_id}_LRStd.txt
    		
    		Lmean=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_mask}/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}.nii.gz -M)
    		LStd=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_mask}/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_left_${thr_type}.${thr}.nii.gz -S)
    		
    		Rmean=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_mask}/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}.nii.gz -M)
    		RStd=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_mask}/mask_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_right_${thr_type}.${thr}.nii.gz -S)
    
    		LRmean=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_LR}/LR_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_${thr_type}.${thr}.nii.gz -M)
    		LRStd=$(fslstats ${dtifit}/dtifit_FA.nii.gz -k ${tract_LR}/LR_${SeedROI}_${TargetROI}_X_${TargetROI}_${SeedROI}_${thr_type}.${thr}.nii.gz -S)
    
    		echo "${SeedROI}_${TargetROI}, $Lmean, $LStd, $Rmean, $RStd , $LRmean, $LRStd"  >> $stats_saver/${sub_id}_${sess_id}_results.txt
    		
    	
    done < ${files_dir}/ROI_List_single_short.csv 
    	
echo "----------- ANALYSIS COMPLETED FOR SUBJECT ${sub_id} ${sess_id} --------------------------------" 

