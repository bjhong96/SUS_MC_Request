#!/bin/bash

export SCRAM_ARCH=slc7_amd64_gcc700

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_19/src ] ; then
  echo release CMSSW_10_6_19 already exists
else
  scram p CMSSW CMSSW_10_6_19
fi
cd CMSSW_10_6_19/src
eval `scram runtime -sh`

mv ../../Configuration .
scram b
cd ../..

# Maximum validation duration: 28800s
# Margin for validation duration: 30%
# Validation duration with margin: 28800 * (1 - 0.30) = 20160s
# Time per event for each sequence: 48.0000s
# Threads for each sequence: 1
# Time per event for single thread for each sequence: 1 * 48.0000s = 48.0000s
# Which adds up to 48.0000s per event
# Single core events that fit in validation duration: 20160s / 48.0000s = 420
# Produced events limit in McM is 10000
# According to 0.2350 efficiency, validation should run 10000 / 0.2350 = 42553 events to reach the limit of 10000
# Take the minimum of 420 and 42553, but more than 0 -> 420
# It is estimated that this validation will produce: 420 * 0.2350 = 98 events
EVENTS=420

# Random seed between 1 and 100 for externalLHEProducer
SEED=$(($(date +%s) % 100 + 1))


# cmsDriver command
#cmsDriver.py Configuration/GenProduction/python/SUS-RunIISummer15wmLHEGS-00053-fragment.py --python_filename SUS-RunIISummer15wmLHEGS-00053_1_cfg.py --eventcontent RAWSIM,LHE --customise SLHCUpgradeSimulations/Configuration/postLS1Customs.customisePostLS1,Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM,LHE --fileout file:SUS-RunIISummer15wmLHEGS-00053.root --conditions MCRUN2_71_V1::All --beamspot Realistic50ns13TeVCollision --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" --step LHE,GEN,SIM --magField 38T_PostLS1 --no_exec --mc -n $EVENTS || exit $? ;
cmsDriver.py Configuration/GenProduction/python/SUS-RunIISummer15wmLHEGS-00053-fragment.py --python_filename SUS-RunIISummer15wmLHEGS-00053_1_cfg.py --eventcontent RAWSIM,LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM,LHE --fileout file:SUS-RunIISummer15wmLHEGS-00053.root --conditions 102X_upgrade2018_realistic_v11 --beamspot Realistic25ns13TeVEarly2018Collision --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" --step LHE,GEN,SIM --geometry DB:Extended --era Run2_2018 --no_exec --mc -n $EVENTS || exit $? ;

# Run generated config
REPORT_NAME=SUS-RunIISummer15wmLHEGS-00053_report.xml
# Run the cmsRun
cmsRun -e -j $REPORT_NAME SUS-RunIISummer15wmLHEGS-00053_1_cfg.py || exit $? ;

# Parse values from SUS-RunIISummer15wmLHEGS-00053_report.xml report
processedEvents=$(grep -Po "(?<=<Metric Name=\"NumberEvents\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
producedEvents=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" $REPORT_NAME | tail -n 1)
threads=$(grep -Po "(?<=<Metric Name=\"NumberOfThreads\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
peakValueRss=$(grep -Po "(?<=<Metric Name=\"PeakValueRss\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
peakValueVsize=$(grep -Po "(?<=<Metric Name=\"PeakValueVsize\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalSize=$(grep -Po "(?<=<Metric Name=\"Timing-tstoragefile-write-totalMegabytes\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalSizeAlt=$(grep -Po "(?<=<Metric Name=\"Timing-file-write-totalMegabytes\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalJobTime=$(grep -Po "(?<=<Metric Name=\"TotalJobTime\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalJobCPU=$(grep -Po "(?<=<Metric Name=\"TotalJobCPU\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
eventThroughput=$(grep -Po "(?<=<Metric Name=\"EventThroughput\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
avgEventTime=$(grep -Po "(?<=<Metric Name=\"AvgEventTime\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
if [ -z "$threads" ]; then
  echo "Could not find NumberOfThreads in report, defaulting to 1"
  threads=1
fi
if [ -z "$eventThroughput" ]; then
  eventThroughput=$(bc -l <<< "scale=4; 1 / ($avgEventTime / $threads)")
fi
if [ -z "$totalSize" ]; then
  totalSize=$totalSizeAlt
fi
if [ -z "$processedEvents" ]; then
  processedEvents=$EVENTS
fi
echo "Validation report of SUS-RunIISummer15wmLHEGS-00053 sequence 1/1"
echo "Processed events: $processedEvents"
echo "Produced events: $producedEvents"
echo "Threads: $threads"
echo "Peak value RSS: $peakValueRss MB"
echo "Peak value Vsize: $peakValueVsize MB"
echo "Total size: $totalSize MB"
echo "Total job time: $totalJobTime s"
echo "Total CPU time: $totalJobCPU s"
echo "Event throughput: $eventThroughput"
echo "CPU efficiency: "$(bc -l <<< "scale=2; ($totalJobCPU * 100) / ($threads * $totalJobTime)")" %"
echo "Size per event: "$(bc -l <<< "scale=4; ($totalSize * 1024 / $producedEvents)")" kB"
echo "Time per event: "$(bc -l <<< "scale=4; (1 / $eventThroughput)")" s"
echo "Filter efficiency percent: "$(bc -l <<< "scale=8; ($producedEvents * 100) / $processedEvents")" %"
echo "Filter efficiency fraction: "$(bc -l <<< "scale=10; ($producedEvents) / $processedEvents")
echo "HIHIHIHIHIHI"

# End of SUS-RunIISummer15wmLHEGS-00053_test.sh file
