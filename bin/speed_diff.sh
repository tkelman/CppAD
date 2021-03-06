#! /bin/bash -e
# $Id$
# -----------------------------------------------------------------------------
# CppAD: C++ Algorithmic Differentiation: Copyright (C) 2003-14 Bradley M. Bell
#
# CppAD is distributed under multiple licenses. This distribution is under
# the terms of the 
#                     Eclipse Public License Version 1.0.
#
# A copy of this license is included in the COPYING file of this distribution.
# Please visit http://www.coin-or.org/CppAD/ for information on other licenses.
# -----------------------------------------------------------------------------
if [ "$0" != 'bin/speed_diff.sh' ]
then
	echo 'bin/speed_diff.sh: must be executed from its parent directory'
	exit 1
fi
if [ "$2" == '' ]
then
cat << EOF
usage: bin/speed_diff.sh speed_one.out speed_two.out
where speed_one.out and speed_two.out are outputs from the speed_cppad program
runing its 'speed' test.
EOF
	exit 1
fi
speed_one="$1"
speed_two="$2"
if [ ! -f "$speed_one" ]
then
	echo "speed_diff.sh: the file $speed_one does not exist."
	exit 1
fi
if [ ! -f "$speed_two" ]
then
	echo "speed_diff.sh: the file $speed_two does not exist."
	exit 1
fi
#
sed -n \
	-e 's|^[a-z]*_||' \
	-e 's|_rate|_rate_one|' -e '/_rate_one/p' \
	-e 's|available|available_one|' -e '/available_one/p' \
	$speed_one > speed_diff.$$
#
sed -n \
	-e 's|^[a-z]*_||' \
	-e 's|_rate|_rate_two|' -e '/_rate_two/p' \
	-e 's|available|available_two|' -e '/available_two/p' \
	$speed_two >> speed_diff.$$
#
cat speed_diff.$$ | sort -u
rm speed_diff.$$
