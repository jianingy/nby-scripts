#!/usr/bin/perl -i

# filename   : install-hostbased-ssh.pl
# created at : 2012-12-03 19:10:18
# author     : Jianing Yang <jianingy.yang AT gmail DOT com>

use strict;
use warnings;

use Getopt::Std;

use vars '$opt_h', '$opt_u';

BEGIN {
        if (!getopts('hu') || $opt_h) {
                print STDERR "Usage: $0 [-u] \n";
                print STDERR "enable or disable (with -u) hostbased ssh authentication.\n";
                exit;
        }
}

##############################################################################
#
# EDIT /etc/sshd_config
#
##############################################################################

{
    @ARGV=qw(/etc/ssh/sshd_config);

    while(<>) {
	s/^\s*HostbasedAuthentication\s+\w+[\r\n]?//g if m/^\s*HostbasedAuthentication\s+\w+/;
	s/^\s*IgnoreRhosts\s+\w+[\r\n]?//g if m/^\s*IgnoreRhosts\s+\w+/;
	print;
	if (eof) {
	    if ($opt_u) {
		print "HostbasedAuthentication no\n";
		print "IgnoreRhosts yes\n";
	    } else {
		print "HostbasedAuthentication yes\n";
		print "IgnoreRhosts no\n";
	    }
	}
    }
}

##############################################################################
#
# EDIT /etc/ssh_config
#
##############################################################################

{
    @ARGV=qw(/etc/ssh/ssh_config);

    my $star = 0;
    while(<>) {
	if (m/^\s*Host\s+(.+)/) {
	    if ($1 =~ /^\*$/) {
	       $star = 1;
	    } else {
	       $star = 0;
	    }
	}

	s/^\s*HostbasedAuthentication\s+\w+[\r\n]?//g if m/^\s*HostbasedAuthentication\s+\w+/;
	s/^\s*EnableSSHKeysign\s+\w+[\r\n]?//g if m/^\s*EnableSSHKeysign\s+\w+/;
	print;
	if (eof) {
	    print "Host *\n" unless $star;
	    if ($opt_u) {
		print "\tHostbasedAuthentication no\n";
		print "\tEnableSSHKeysign no\n";
	    } else {
		print "\tHostbasedAuthentication yes\n";
		print "\tEnableSSHKeysign yes\n";
	    }
	}
    }
}
