#!/usr/bin/perl -i -w

# filename   : install-console.pl
# created at : 2012年08月10日 星期五 14时08分45秒
# author     : Jianing Yang <shiqian@taobao.com>

use strict;
use warnings;
use Getopt::Long;

##############################################################################
#
# EDIT /etc/inittab
#
##############################################################################
{
	my ($auto, $force, $conf) = (0, 0, undef);
	GetOptions ('auto' => \$auto, 'force' => \$force);
	$auto = 1 if @ARGV && $ARGV[0] eq '--auto';
	@ARGV=qw(/etc/inittab);
	if ($auto) {
	    $conf = 's0:12345:respawn:/sbin/agetty ttyS0 -L 57600 vt100 -n -l /bin/bash'
	} else {
		$conf = 's0:12345:respawn:/sbin/agetty ttyS0 -L 57600 vt100';
	}
	while(<>) {
		if (m#^\s*s[0-9]:[0-9]+:respawn:/sbin/agetty ttyS[0-9]#) {
			if ($force) {
			} else {
				$conf = undef;
			    print;
			}
		} else {
			print;
		}
		print "$conf\n" if eof && $conf;
	}
	print STDERR "console already set" unless $conf;
}
