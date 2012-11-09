#! /bin/bash -e
# $Id$
# -----------------------------------------------------------------------------
# CppAD: C++ Algorithmic Differentiation: Copyright (C) 2003-12 Bradley M. Bell
#
# CppAD is distributed under multiple licenses. This distribution is under
# the terms of the
#                     Eclipse Public License Version 1.0.
#
# A copy of this license is included in the COPYING file of this distribution.
# Please visit http://www.coin-or.org/CppAD/ for information on other licenses.
# -----------------------------------------------------------------------------
if [ ! -e "bin/run_cmake.sh" ]
then
	echo "bin/run_cmake.sh: must be executed from its parent directory"
	exit 1
fi
echo_exec() {
     echo $* 
     eval $*
}
echo_exec_log() {
	echo "$* >> run_cmake.log"
	echo    >> $log_file
	eval $* >> $log_file
}
# circular shift program list and set program to first entry in list
next_program() {
	program_list=`echo "$program_list" | sed -e 's| *\([^ ]*\) *\(.*\)|\2 \1|'`
	program=`echo "$program_list" | sed -e 's| *\([^ ]*\).*|\1|'`
}
# -----------------------------------------------------------------------------
cmake_args=''
if [ "$1" != "" ]
then
	if [ "$1" == '--verbose' ]
	then
		cmake_args="$cmake_args  -DCMAKE_VERBOSE_MAKEFILE=1"
	else
		echo 'usage: bin/run_cmake.sh: [--verbose]'
		exit 1
	fi
fi
cmake_args="$cmake_args  -Dcppad_prefix=$HOME/prefix/cppad"
# -----------------------------------------------------------------------------
list="
	run_cmake.log
	$HOME/prefix/cppad
	work
"
for name in $list
do
	if [ -e "$name" ]
	then
		echo_exec rm -r $name
	fi
done
echo_exec mkdir work
echo_exec cd work
log_file="../run_cmake.log"
# -----------------------------------------------------------------------------
if [ -d '/usr/include' ]
then
	cmake_args="$cmake_args -Dcmake_install_includedir=include"
fi
#
if [ -d '/usr/share' ]
then
	cmake_args="$cmake_args -Dcmake_install_datadir=share"
fi
#
if [ -d '/usr/lib64' ]
then
	cmake_args="$cmake_args -Dcmake_install_libdir=lib64"
elif [ -d '/usr/lib' ]
then
	cmake_args="$cmake_args -Dcmake_install_libdir=lib"
fi
#
for package in adolc eigen ipopt fadbad sacado
do
	dir=$HOME/prefix/$package
	if [ -d "$dir" ]
	then
		cmake_args="$cmake_args  -D${package}_prefix=$dir"
	fi
done
cmake_args="$cmake_args -Dcppad_sparse_list=YES"
cmake_args="$cmake_args -Dcppad_test_vector_namespace=boost"
cmake_args="$cmake_args -Dcppad_tape_id_type='unsigned int'"
cmake_args="$cmake_args -Dcppad_tape_addr_type=int"
cmake_args="$cmake_args -Dcppad_max_num_threads=16"
#
echo_exec_log cmake .. $cmake_args
echo_exec_log make all 
# -----------------------------------------------------------------------------
skip=''
list='
	example/example
	test_more/test_more
	cppad_ipopt/example/ipopt_example
	cppad_ipopt/speed/ipopt_speed
	cppad_ipopt/test/ipopt_test_more
	speed/example/speed_example
'
#
# standard tests
for program in $list
do
	if [ ! -e "$program" ]
	then
		skip="$skip $program"
	else
		echo_exec_log $program 
	fi
done
#
# speed tests
for dir in adolc cppad double fadbad sacado profile
do
	program="speed/$dir/speed_${dir}"
	if [ ! -e "$program" ]
	then
		skip="$skip $program"
	else
		echo_exec_log $program correct 54321 
		echo_exec_log $program correct 54321 retape
	fi
done
#
# multi_thread tests
# ----------------------------------------------------------------------------
program_list=''
for dir in bthread openmp pthread
do
	program="multi_thread/${dir}/${dir}_test"
	if [ ! -e $program ]
	then
		skip="$skip $program"
	else
		program_list="$program_list $program"
		#
		# fast cases, test for all programs
		echo_exec_log ./$program a11c
		echo_exec_log ./$program simple_ad
		echo_exec_log ./$program team_example
	fi
done
if [ "$program_list" != '' ]
then
	# test_time=1,max_thread=4,mega_sum=1
	next_program
	echo_exec_log ./$program harmonic 1 4 1
	# 
	# test_time=2,max_thread=4,num_zero=20,num_sub=30,num_sum=500,use_ad=true
	next_program
	echo_exec_log ./$program multi_newton 2 4 20 30 500 true
	#
	# case that failed in the past
	next_program
	echo_exec_log ./$program multi_newton 1 1 100 700 1 true
	#
	# case that failed in the past
	next_program
	echo_exec_log ./$program multi_newton 1 2 3 12 1 true
fi
#
# print_for test 
if [ ! -e 'print_for/print_for' ]
then
	skip="$skip print_for/print_for"
else
	echo_exec_log print_for/print_for 
	print_for/print_for | sed -e '/^Test passes/,$d' > junk.1.$$
	print_for/print_for | sed -e '1,/^Test passes/d' > junk.2.$$
	if diff junk.1.$$ junk.2.$$
	then
		rm junk.1.$$ junk.2.$$
		echo "print_for: OK"  >> $log_file
	else
		echo "print_for: Error"  >> $log_file
		exit 1
	fi
fi
#
echo_exec_log make install >> $log_file
#
if [ "$skip" != '' ]
then
	echo "run_cmake.sh: skip = $skip"
	exit 1
fi
#
echo 'run_cmake.sh: OK'
exit 0