#!/bin/bash
export SOURCES=$PWD

spack load openfoam@2112 %gcc@11.3.1

export INPUT=$SOURCES/bench_template

source /mnt/share/hpc_automation/apps/openfoam/2112/aocc/3.2.0/openmpi/4.1.1/aocc/3.2.0/OpenFOAM-v2112/etc/bashrc
rm -vrf Motorbike_bench_template.tar.gz bench_template

wget http://openfoamwiki.net/images/6/62/Motorbike_bench_template.tar.gz
tar -xzvf Motorbike_bench_template.tar.gz


cd $INPUT
sed -i '/#include "streamLines"/c\ ' basecase/system/controlDict
sed -i '/#include "wallBoundedStreamLines"/c\ ' basecase/system/controlDict
unset FOAM_SIGFPE
export FOAM_SIGFPE=false
export UprofCLI=/home/amd/AMDuprof/AMDuProf_Linux_x64_4.0.341/bin/AMDuProfCLI
# Prepare cases
which snappyHexMesh

for i in 64 128; do
    d=run_$i
    echo "Prepare case ${d}..."
    cp -r basecase $d
    cd $d
    pwd
    if [ $i -eq 1 ]
    then
        mv Allmesh_serial Allmesh
    elif [ $i -gt 128 ]
    then
        sed -i "s|runParallel snappyHexMesh -overwrite|mpirun -np ${i} -mca btl vader,self  --map-by hwthread -use-hwthread-cpus  snappyHexMesh -parallel -overwrite > log.snappyHexMesh|" Allmesh
    fi
    sed -i "s/method.*/method scotch;/" system/decomposeParDict
    sed -i "s/numberOfSubdomains.*/numberOfSubdomains ${i};/" system/decomposeParDict
    ./Allmesh
    cd ..
done
# Run cases
for i in 64 128; do
    echo "Run for ${i}..."
    cd run_$i
    if [ $i -eq 1 ]
    then
        simpleFoam > log.simpleFoam 2>&1
    elif [ $i -gt 128 ]
    then
        mpirun -np ${i} -report-bindings --map-by hwthread  -use-hwthread-cpus -mca btl vader,self $UprofCLI collect --config tbp --mpi -w /home/amd/benchmark/bench_template/run_128 --output-dir $PWD/tbp-profiling simpleFoam -parallel:-np ${i} --bind-to core --map-by core simpleFoam -parallel  > log.simpleFoam 2>&1
        sed -i "s|mpirun -np ${i} --map-by hwthread -use-hwthread-cpus  snappyHexMesh -parallel -overwrite > log.snappyHexMesh|runParallel snappyHexMesh -overwrite|" Allmesh
    else
        mpirun -np ${i} --map-by core  simpleFoam -parallel > log.simpleFoam 2>&1
    fi
    cd ..
done
echo "# cores   Wall time (s):"
echo "------------------------"
for i in 64 128 ; do
    echo $i `grep Execution run_${i}/log.simpleFoam | tail -n 1 | cut -d " " -f 3`
done
