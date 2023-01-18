#!/bin/env python
# -*- coding: utf-8 -*-


import math
import psutil
import subprocess
import argparse

# Modify the following three variables as appropriate:
physical_cores_per_ccx = 4 # This is specific to your AMD EPYC CPU
percent_mem = 92 # Specify the portion of memory to use
NB = 240 # HPL block size

appfile_name = "appfile_ccx"

# CONSTANTS:
ONE_GIBIBYTE = 1024**3
DP_SIZE = 8
EOL = "\n"

# parse command line arguments for:
#     physical_cores_per_ccx: the number of physical cores per ccx
#     percent_mem: % of memory used for HPL
#     NB: block size
def parse_command_line_args( parser ):
    global physical_cores_per_ccx, percent_mem, NB, mem_GiB

    # add arguments:
    parser.add_argument("--nb", "-nb", help="set block size (int)", type=int)
    parser.add_argument("--percent_mem", "-pm", help="specify percentage memory to use (int)", type=int)
    parser.add_argument("--physical_cores_per_ccx", "-pcpc", help="number of physical cores per ccx (int)", type=int)
    parser.add_argument("--memory_GiB", "-mgb", help="DRAM memory in GiB (int)", type=int)

    # read arguments from command line:
    args = parser.parse_args()
    if args.nb:
        NB = args.nb
        print( 'Commmand line argument supplied: The block size (NB) is now set to: ' + str( NB ) )
    if args.percent_mem:
        percent_mem = args.percent_mem
        print( 'Commmand line argument supplied: The percentage of memory to be used is now set to: ' + str( percent_mem ) )
    if args.physical_cores_per_ccx:
        physical_cores_per_ccx = args.physical_cores_per_ccx
        print( 'Commmand line argument supplied: The number of physical cores per CCX is now set to: ' + str( physical_cores_per_ccx ) )
    if args.memory_GiB:
        mem_GiB = args.memory_GiB
        print( 'Commmand line argument supplied: The total system memory (GiB) is now set to: ' + str( mem_GiB ) )

def generate_appfile():
    result = ''
    numa_node = ccx_nbr = 0
    prefix = '-np 1 ./xhpl_ccx.sh '
    postfix = ' ' + str( physical_cores_per_ccx )
    for pcore in range(0, physical_cores, physical_cores_per_ccx):
        xhpl_aff = str(pcore) + '-' + str(pcore + physical_cores_per_ccx - 1)
        numa_node = int( ccx_nbr / ccx_per_numa_node )
        result += prefix + str(numa_node) + ' ' + xhpl_aff + postfix + EOL
        ccx_nbr += 1  
    return result
    
def generate_appfile_logical_cores():
    result = ''
    numa_node = ccx_nbr = 0
    prefix = '-np 1 ./xhpl_ccx.sh '
    postfix = ' ' + str( physical_cores_per_ccx )
    for pcore in range(0, physical_cores, physical_cores_per_ccx):
        xhpl_aff = str(pcore) + '-' + str(pcore + physical_cores_per_ccx - 1) + ',' + \
            str(pcore + physical_cores) + \
            '-' + str(pcore + physical_cores + physical_cores_per_ccx - 1)
        numa_node = int( ccx_nbr / ccx_per_numa_node )
        result += prefix + str(numa_node) + ' ' + xhpl_aff + postfix + EOL
        ccx_nbr += 1  
    return result

def generate_hpl_dat(a_n, a_nb, a_p, a_q):
    result = '''HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out     output file name (if any)
6           device out (6=stdout,7=stderr,file)
1           # of problems sizes (N)
nnnnnn      Ns
1           # of NBs
nbnbnb      # of problems sizes (N)
0           MAP process mapping (0=Row-,1=Column-major)
1           # of process grids (P x Q)
pppppp      Ps
qqqqqq      Qs
16.0        threshold
1           # of panel fact<
2           PFACTs (0=left, 1=Crout, 2=Right)
1           # of recursive stopping criterium
4           NBMINs (>= 1)
1           # of panels in recursion
2           NDIVs
1           # of recursive panel fact.
1           RFACTs (0=left, 1=Crout, 2=Right)
1           # of broadcast
1           BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1           # of lookahead depth
1           DEPTHs (>=0)
2           SWAP (0=bin-exch,1=long,2=mix)
64          swapping threshold
0           L1 in (0=transposed,1=no-transposed) form
0           U in (0=transposed,1=no-transposed) form
1           Equilibration (0=no,1=yes)
8           memory alignment in double (> 0)'''.replace('nnnnnn', str(a_n) + ' '*(6 - len(str(a_n)) ))
    result = result.replace('nbnbnb',str(a_nb) + ' '*(6 - len(str(a_nb))))
    result = result.replace('pppppp',str(a_p) + ' '*(6 - len(str(a_p))))
    result = result.replace('qqqqqq',str(a_q) + ' '*(6 - len(str(a_q))))
    return result

def get_numa_node_count():
    return int(subprocess.check_output("numactl --hardware | grep \"available:\" | awk '{print $2}'", shell=True))
    
def get_socket_count():
    return int( subprocess.check_output( "lscpu | grep 'Socket(s)' | awk '{print $2}'", shell=True ))

def get_numa_node_min_mem_GiB():
    return float(subprocess.check_output("numactl -H | grep size: | awk '{print $4}' | sort -n | head -1", shell=True)) / 1024

def get_physical_cores_per_socket():
    return int(subprocess.check_output( "lscpu | grep 'Core(s) per socket' | awk '{print $4}'", shell=True ))
    
def get_physical_cores_total():
    return get_socket_count() * get_physical_cores_per_socket()

def get_mem_GiB():
    return int( float(psutil.virtual_memory()[0]) / ONE_GIBIBYTE )

def calculate_N():
    # Calculate N based upon the amount of system memory and the percentage
    # specified to be used:
    global mem_GiB, ONE_GIBIBYTE, DP_SIZE, percent_mem, NB
    N = math.sqrt( mem_GiB * ONE_GIBIBYTE / DP_SIZE ) * (float(percent_mem)/100)
    # Calculate the number of blocks that can be used:
    nbr_blocks = int( N / NB )
    # Recalculate N to be the product of the number of block and block size
    N = NB * nbr_blocks
    return N
    
### Main program ###

numa_node_count = get_numa_node_count()
print( 'The NUMA node count is ' + str( numa_node_count ))
socket_count = get_socket_count()
print( 'The system socket count is ' + str(socket_count) )
numa_min_mem = get_numa_node_min_mem_GiB()
print( 'The lowest NUMA node memory amount (GiB) is ' + str( numa_min_mem ) )
if numa_min_mem == 0:
    print( '*** One or more of your NUMA nodes do not have memory installed! ***' )
    print( '*** This script does not handle that configuration.              ***' )
    print( '*** You will need to either install memory on all NUMA nodes or  ***' )
    print( '*** you will have to manually set up the run. Exiting script...  ***' )
    quit()
physical_cores = get_physical_cores_total()
print( 'The number of physical cores detected: ' + str( physical_cores ))
mem_GiB = get_mem_GiB()
mem_GiB_min = int( numa_node_count * numa_min_mem )
if mem_GiB_min < mem_GiB:
    print( 'The calculated minimum NUMA node memory amount was ' + str( mem_GiB_min ) + ' GiB.')
    print( 'The adjusted memory amount is ' + str( mem_GiB_min ) + ' GiB versus detected total of ' + str( mem_GiB ) + ' GiB.')
    mem_GiB = mem_GiB_min
else:
    print( 'The calculated minimum NUMA node memory amount was ' + str( mem_GiB_min ) + ' GiB.')
    print( 'Using the original detected memory amount of ' + str( mem_GiB ) + ' GiB.')
ccx_total = physical_cores / physical_cores_per_ccx
ccx_per_numa_node = ccx_total / numa_node_count
nbr_of_processes = ccx_total
if nbr_of_processes == 4:
    p = 2
    q = 2
elif nbr_of_processes == 8:
    p = 2
    q = 4
elif nbr_of_processes == 16:
    p = 4
    q = 4
elif nbr_of_processes == 24:
    p = 4
#    q = 6
elif nbr_of_processes == 32:
    p = 4
    q = 8

parse_command_line_args( argparse.ArgumentParser(description='HPL configuration file generator.') )
N = calculate_N()
print( "The optimal N setting for your SUT is " + str( N ) + EOL )

file = open("HPL.dat","w")
hpl_txt = generate_hpl_dat(N, NB, p, q)
file.write( hpl_txt )
print( 'HPL.dat:' )
print( hpl_txt )
file.close()

print

file = open(appfile_name,"w")
appfile_txt = generate_appfile()
file.write( appfile_txt  )
print( appfile_name + ':')
print( appfile_txt )
file.close()

