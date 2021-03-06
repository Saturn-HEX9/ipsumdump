#! /bin/bash

usage () {
    echo "Usage: ./bootstrap.sh [CLICKBUILDDIR]" 1>&2
    exit 1
}

libclickversion () {
    grep 'AC_DEFUN.*AC_LIBCLICK_VERSION' configure.ac | sed 's/^.*\[\([0-9.]*\)\].*/\1/'
}

if test -n "$1"; then
    [ -d "$1" ] || usage
    [ -d "$1/etc/libclick" ] || usage

    if [ ! -f ipsumdump.pod ]; then
	echo "sourcecheckout.sh must be run from the top ipsumdump source directory" 1>&2
	usage
    fi

    version=`grep "^VERSION" "$1/etc/libclick/Makefile" | sed 's/.*= *//'`
    if [ -z "$version" ]; then
	echo "Bad CLICKBUILDDIR/etc/libclick/Makefile: no VERSION defined!" 1>&2
	usage
    fi

    my_libclick_version=`libclickversion`
    if [ "$my_libclick_version" != "$version" ]; then
	cp configure.ac configure.ac~ || exit 1
	echo "Updating configure.ac to libclick-$version" 1>&2
	sed 's/^\(AC_DEFUN.*AC_LIBCLICK_VERSION.*\[\)[0-9.]*\(\].*\)$/\1'"$version"'\2/' < configure.ac~ > configure.ac
    fi

    click_top_srcdir=`grep "^top_srcdir" "$1/Makefile" | sed 's/.*= *//'`
    if [ -z "$click_top_srcdir" ]; then
	echo "Bad CLICKBUILDDIR/Makefile: no top_srcdir defined!" 1>&2
	usage
    fi

    if expr "$click_top_srcdir" : "/.*" >/dev/null 2>&1; then :; else
	click_top_srcdir="$1/$click_top_srcdir"
    fi

    make -C $1/etc/libclick dist || exit 1
    if [ ! -f "$1/etc/libclick/libclick-$version.tar.gz" ]; then
	echo "make -C CLICKBUILDDIR/etc/libclick dist failed to make libclick-$version.tar.gz!" 1>&2
	usage
    fi

    gzcat=zcat
    if which gzcat 2>&1 | grep -v '^\(which: \)*no' >/dev/null && which gzcat 2>/dev/null | grep . >/dev/null; then
	gzcat=gzcat
    fi

    $gzcat "$1/etc/libclick/libclick-$version.tar.gz" | tar xf -

    for fgroup in `cat CLICKFILES`; do
	alteration=`echo "$fgroup" | sed 's/[^:]*://'`
	fgroup=`echo "$fgroup" | sed 's/:.*//'`
	for f in `cd "$click_top_srcdir" && eval echo $fgroup`; do
	    g=`echo $f | sed 's/.*\/\([^/]*\)$/\1/'`
	    rm -f src/$g
	    ln "$click_top_srcidr/$f" src/$g 2>/dev/null \
		|| cp -p "$click_top_srcdir/$f" src/$g \
		|| { echo "Could not copy CLICKSRCDIR/$f!" 1>&2; exit 1; }
	    test "$alteration" = "$fgroup" || perl -pi -e "$alteration" src/$g
	done
    done
fi

aclocal -I libclick-`libclickversion`/m4
autoconf
