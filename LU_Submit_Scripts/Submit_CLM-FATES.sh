#!/bin/bash 

#Scrip to clone, build, run and analyze CLM-FATES simulation.

dosetup=0 #do we want to create parameters files and so on?
dosubmit=1 #do we do the submission stage, or just the analysis?
forcenewcase=1 #do we scurb all the old cases and start again?
doanalysis=0 #do we want to plot the outputs? 

echo "setup, submit, analysis:", $dosetup, $dosubmit, $doanalysis 

USER="kjetisaa"
project='nn8057k' #nn8057k: EMERALD, nn2806k: METOS, nn9188k: CICERO
machine='betzy'
setCPUs=1 #For setting number of CPUs. 1: 1024

# what is your clone of the ctsm repo called? (or you want it to be called?) 
ctsmrepo="March2023-CLMFATES" 
versiontag="v1"

#path to scratch (or where the model is built.)
scratch="/cluster/work/users/$USER/"
#where are we now?
startdr=$(pwd)
# aka where do you want the code and scripts to live?
workpath="/cluster/work/users/$USER/" #previously: 'gitpath'
# some more derived path names to simplify latter scripts
scriptsdir=$workpath$ctsmrepo/cime/scripts/

#path to results (history) 
results_dir="/cluster/work/users/$USER/"

#case charecteristics
# resolution=
#resolution='f09_g17' #'f09_g17', 'f19_g17', 'f45_f45_mg37'
#scenario="HIST" #1850, HIST, 2000, SSP126, SSP119, SSP245, SSP370, SSP434, SSP460, SSP534, SSP585
#config_opt=1 #0: SP, 1: BGC, 2: BGC-CROP, 3: FATES SP, 4: NOCOMP, 5: FIXED BIOGEO, 6: FULL FATES
#modelconfig="FATES" #FATES, SP, BGC, BGC-CROP
forcing=0  #0: Standard GSWP3, 1: ISIMIP UKESM forcing from Wim's scripts

#Duplicated in some config options (e.g. spinup)
stop_n="5"
stop_opt="nyears"
job_wc_time="00:59:00"
resub="0"
spinup=0
config_opt=3


if [ $config_opt -eq 0 ]
then
    modelconfig="BGC-CROP" 
    resolution='f19_g17'
    nl_casesetup_string=""
    fatesversion="lowres"  
    restart 
elif [ $config_opt -eq 1 ]
then
    modelconfig="BGC-CROP" 
    resolution='f19_g17'
    nl_casesetup_string=""
    fatesversion="lowres"  
elif [ $config_opt -eq 2 ]
then
    modelconfig="BGC-CROP" 
    resolution='f19_g17'
    nl_casesetup_string=""
    fatesversion="lowres"  
elif [ $config_opt -eq 3 ]
then
    modelconfig="BGC-CROP" 
    resolution='f19_g17'
    nl_casesetup_string=""
    fatesversion="lowres"  
    resub="0"
    dospinup=0              
fi

casename="${modelconfig}_${fatesversion}${scenario}_${versiontag}_Forc$forcing"
casename_AD="${modelconfig}_${fatesversion_AD}${scenario}_$versiontag"
compset="${scenario}_DATM%GSWP3v1_CLM51%${modelconfig}_SICE_SOCN_SROF_SGLC_SWAV_SESP"
echo $casename
echo $compset
#Download code and checkout externals
if [ $dosetup -eq 1 ] 
then
    cd $workpath

    pwd
    #go to repo, or checkout code
    if [[ -d "$ctsmrepo" ]] 
    then
        cd $ctsmrepo
        echo "Already have ctsm repo"
    else
        echo "Cloning ctsm"
        #clone CTSM code if you didn't to this already. 
        git clone https://github.com/escomp/ctsm $ctsmrepo
        cd $ctsmrepo
        module load git/2.23.0-GCCcore-8.3.0  #Default git version on betzy is too old
        ./manage_externals/checkout_externals
        cd src
        module purge
    fi
fi

#Make case
if [[ $dosetup -eq 1 ]] 
then
    cd $scriptsdir

    if [[ $forcenewcase -eq 1 ]]
    then 
        if [[ -d "$casename" ]] 
        then    
        echo "$casename exists on your filesystem. Removing it!"
        rm -r /cluster/work/users/kjetisaa/ctsm/$casename
        rm -r /cluster/work/users/kjetisaa/archive/$casename
        rm -r $casename
        fi
    fi
    if [[ -d "$casename" ]] 
    then    
        echo "$casename exists on your filesystem."
    else
        
        echo "making case:" $casename
        ./create_newcase --case $casename --compset $compset --res $resolution  --run-unsupported --project $project --machine $machine
        cd $casename

        #XML changes
        echo 'updating settings'
        ./xmlchange CONTINUE_RUN=FALSE
        ./xmlchange --id STOP_N --val $stop_n
        ./xmlchange --id STOP_OPTION --val $stop_opt
        #./xmlchange --id CLM_FORCE_COLDSTART --val on 
        ./xmlchange --subgroup case.run JOB_WALLCLOCK_TIME=$job_wc_time
        #./xmlchange DATM_YR_ALIGN=1851
        #./xmlchange DATM_YR_START=1851
        #./xmlchange DATM_YR_END=1871
        ./xmlchange DATM_YR_END=1905 #Test
        if [ $forcing -eq 1 ] 
        then
            ./xmlchange DIN_LOC_ROOT_CLMFORC='/cluster/work/users/kjetisaa/isimip_forc/historical/UKESM1-0-LL/'
        fi
        if [[ $dospinup -eq 1 ]]
        then 
            ./xmlchange CLM_ACCELERATED_SPINUP="on"
            ./xmlchange RESUBMIT=$resub
            echo 'Accelerated spinup'
        elif [[ $dospinup -eq 2 ]]
        then 
            #code copied from https://escomp.github.io/ctsm-docs/versions/master/html/users_guide/running-special-cases/Spinning-up-the-biogeochemistry-BGC-spinup.html
            # Now, Copy the last CLM restart file from the earlier case into your run directory
            cp /cluster/work/users/kjetisaa/archive/$casename_AD/rest/*clm.r*.nc /cluster/work/users/kjetisaa/ctsm/$casename/run/
            # Set the runtype to startup
            ./xmlchange RUN_TYPE=startup
            # And copy the rpointer files for datm and drv from the earlier case
            cp /cluster/work/users/kjetisaa/archive/$casename_AD/rest/rpointer.atm /cluster/work/users/kjetisaa/ctsm/$casename/run/
            echo 'List files in run folder (after copy restart):'
            ls -l /cluster/work/users/kjetisaa/ctsm/$casename/run/
            # Set the finidat file to the last restart file saved in previous step
            echo " finidat = ${casename_AD}.clm2.r.0201-01-01-00000.nc" > user_nl_clm
            # Now setup                               
            ./xmlchange RESUBMIT=$resub
        fi

        if [[ $setCPUs -eq 1 ]]
        then 
            echo 'setting #CPUs to 1024'    
            ./xmlchange NTASKS_ATM=1024
            ./xmlchange NTASKS_OCN=1024
            ./xmlchange NTASKS_LND=1024
            ./xmlchange NTASKS_ICE=1024
            ./xmlchange NTASKS_ROF=1024
            ./xmlchange NTASKS_GLC=1024         
        fi
        echo 'done with xmlchanges'        
        
        ./case.setup

        echo $nl_casesetup_string >> user_nl_clm
        tail -n 10 user_nl_clm

        ./case.build
    fi
fi
#echo "Currently in" $(pwd)

#Submit job
if [[ $dosubmit -eq 1 ]] 
then
    cd $scriptsdir/$casename
    ./case.submit
    echo 'done submitting'  
    cd $startdr  

    #Check job (TODO)
    rund="$scratch/ctsm/$casename/run/"
    echo $rund
    #ls -lrt $rund   
    
    #Store key simulation information and paths
    echo "----$casename----" >> List_of_simulations.txt
    date >> List_of_simulations.txt
    echo /cluster/work/users/kjetisaa/ctsm/$casename/run >> List_of_simulations.txt
    echo /cluster/work/users/kjetisaa/archive/$casename/lnd/hist/ >> List_of_simulations.txt
    echo $scriptsdir/$casename >> List_of_simulations.txt
    echo $compset >> List_of_simulations.txt        
    echo $resolution >> List_of_simulations.txt
    echo $nl_casesetup_string >> List_of_simulations.txt 
    echo '' >> List_of_simulations.txt
fi
