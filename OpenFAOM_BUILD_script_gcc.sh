##### Set the Paths for Working Directory ###
export SOURCES=$PWD
##Set the paths of AOCC ##
export COMPILERROOT=/usr
$COMPILERROOT/bin/gcc -v
if [[ $? -ne 0 ]];
then
        echo "Error: '$COMPILERROOT/bin/gcc -v' returns non-zero. Set the Path of AOCC in COMPILERROOT"
       exit 1
fi
export OPENMP_ROOT=$COMPILERROOT
  
## Set the Paths for OpenMPI ##
export OPENMPIROOT=/home/amd/benchmark
export OPENFOAMROOT=$PWD
  
#### exporting the env ####
export LD_LIBRARY_PATH=${COMPILERROOT}/lib:$LD_LIBRARY_PATH
export INCLUDE=${COMPILERROOT}/include:$INCLUDE
export PATH=${COMPILERROOT}/bin:$PATH
  
#Compiler/tool names
## Set the AOCC compiler and FLAGS  ##
export CC=gcc
export CXX=g++
export F90=gfortran
export F77=gfortran
export FC=gfortran
export AR=llvm-ar
export RANLIB=llvm-ranlib
  
## Set the FLAGS for ROME znver2, for Milan znver3 ##
export OMPI_CC=gcc
export OMPI_CXX=g++
export OMPI_FC=gfortran
export CFLAGS="-O3 -march=znver3 -fPIC  -fopenmp"
export CXXFLAGS="-O3 -march=znver3 -fPIC  -fopenmp"
export FCFLAGS="-O3 -march=znver3 -fPIC  -fopenmp"
export LDFLAGS=" -lz -lm -lrt -Wl,-z,notext"
  
  
echo "###############################################################################"
echo "#                                OpenMPI                                      #"
echo "###############################################################################"
  
### Installing Openmpi ####
  
if [ -e "$OPENMPIROOT/bin/mpicc" ]; # -d $OPENMPIROOT ];
then
        echo "OpenMPI File Exists "
else
        rm -rf openmpi-4.1.1  openmpi
        if [ ! -e "openmpi-4.1.1.tar.bz2" ]
        then
                echo "Downloading openMPI"
                wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.1.tar.bz2
        fi
        tar -xvf openmpi-4.1.1.tar.bz2
        cd openmpi-4.1.1
        ./configure --prefix=$OPENMPIROOT  CC=${CC} CXX=${CXX} FC=${FC} CFLAGS="-O3 -ffast-math  -march=znver3 " CXXFLAGS="-O3 -ffast-math  -march=znver3 "  FCFLAGS="-O3 -ffast-math  -march=znver3 " --enable-mpi-fortran --enable-shared=yes --enable-static=yes  --enable-mpi1-compatibility --disable-hwloc-pci
        make -j 32 2>&1|tee make.log
        make install -j 8 2>&1| tee make_install.log
        cd $OPENMPIROOT/bin
        if [ -e "mpicc" ]
                then
                echo "OPENMPI BUILD SUCCESSFUL"
        else
                echo "OPENMPI BUILD FAILED"
                exit 1
        fi
fi
export PATH=$OPENMPIROOT/bin:$PATH
export LD_LIBRARY_PATH=$OPENMPIROOT/lib:$LD_LIBRARY_PATH
export INCLUDE=$OPENMPIROOT/include:$INCLUDE
  
echo "###################################################################################"
echo "#                                 OpenFOAM                                        #"
echo "###################################################################################"
if [ -d $OPENFOAMROOT/OpenFOAM-v2112 ];
then
        echo "OpenFOAM 2106 - File exists"
else
        cd $OPENFOAMROOT
        wget https://dl.openfoam.com/source/v2112/OpenFOAM-v2112.tgz
        wget https://dl.openfoam.com/source/v2112/ThirdParty-v2112.tgz
  
        tar -xzf OpenFOAM-v2112.tgz
        tar -xzf ThirdParty-v2112.tgz
        cd $OPENFOAMROOT
        export WM_CXXFLAGS="$CFLAGS"
        export WM_CFLAGS="$CXXFLAGS"
  
        #sed -i 's/WM_COMPILER=Gcc/WM_COMPILER=Amd/' $OPENFOAMROOT/OpenFOAM-v2106/etc/bashrc
        #sed -i 's/clang++ -std=c++11/& -pthread/g' $OPENFOAMROOT/OpenFOAM-v2106/wmake/rules/General/Clang/c++
  	sed -i 's/g++ -std=c++11/& -pthread/g' $OPENFOAMROOT/OpenFOAM-v2112/wmake/rules/General/Gcc/c++
        sed -i 's/WM_MPLIB=SYSTEMOPENMPI/WM_MPLIB=OPENMPI/' $OPENFOAMROOT/OpenFOAM-v2112/etc/bashrc
        sed -i 's/FOAM_MPI=openmpi-${openfoam_mpi_version}/FOAM_MPI=openmpi-${openfoam_mpi_version}/g' $OPENFOAMROOT/OpenFOAM-v2112/etc/config.sh/mpi
        comp=Gcc
        source $OPENFOAMROOT/OpenFOAM-v2112/etc/bashrc
        echo $WM_PROJECT_DIR
        echo " Building in progress "
        # Build OpenFOAM-v2106
        cd $OPENFOAMROOT/OpenFOAM-v2112
  
        time ./Allwmake -j  64 all -k 2>&1 |tee  OpenFOAM_AOCC_install.log
        source $OPENFOAMROOT/OpenFOAM-v2112/etc/bashrc
        cd $OPENFOAMROOT/OpenFOAM-v2112/platforms/linux64GccDPInt32Opt/bin/
        if [ -e "simpleFoam" ] && [ -e "blockMesh" ] && [ -e "snappyHexMesh" ] && [ -e "decomposePar" ];
        then
                echo "OPENFOAM BUILD SUCCESSFUL"
        else
                echo "OPENFOAM BUILD Failed"
        fi
fi
