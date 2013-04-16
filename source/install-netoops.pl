#!/usr/bin/env perl

# filename   : install-netoops.pl
# created at : 2012年08月02日 星期四 10时04分43秒
# author     : Jianing Yang <jianingy.yang AT gmail DOT com>

use strict;
use warnings;
use Getopt::Std;

use constant SUDO => qw ( /usr/local/bin/sudo /usr/bin/sudo );
use vars '$opt_t', '$opt_p';
my $CONFIG="/sys/kernel/config";
my $HOME="$CONFIG/netoops";

sub become {
    my $who = $_[0];
    my $uid = getpwnam($who);

    die "must be passed a valid username"
      unless (($who) && (defined($uid)));

    return if $> == $uid;

    my $whoami = getpwuid($>);
    warn "$whoami: This application needs '$who' privileges.  Invoking sudo.\n";

    foreach my $sudo (reverse SUDO) {
    next unless -x $sudo;
    exec($sudo, '-u', $who, $0, @main::ARGV) ||
      die "ERROR: exec returned: $!";
    }

    die "ERROR: unable to find a suitable sudo(1) binary";
}

sub mount_configfs {
    # mount configfs
    mkdir $CONFIG unless -d $CONFIG;
    system("/bin/umount $CONFIG") if -d "$HOME";
    system("/bin/mount -t configfs none $CONFIG")
      and die "ERROR: netoops not supported or filesystem error";
}

sub netoops_set {
    my ($file, $value) = @_;
    print STDERR "set $HOME/target1/$file to $value\n";
    open CF, '>', "$HOME/target1/$file";
    print CF "$value\n";
    close CF;
}

sub main {

    become('root');

    unless (getopts('t:p:') && $opt_t) {
	print STDERR "Usage: $0 -t target [-p port]\n";
	print STDERR "setup netoops on this box.\n\n";
	exit(0);
    }

    my $route = qx{/sbin/ip ro get $opt_t};
    die "ERROR: can not retrieve network information" unless $route;

    my ($gateway_ip, $iface, $local_ip, $mac);
    foreach (split /\n/, $route) {
	chomp;
	if (m/^$opt_t\s+via\s+(\S+)\s+dev\s+(\S+)\s+src\s+(\S+)/) {
	    ($gateway_ip, $iface, $local_ip) = ($1, $2, $3);
	    my $arp = qx{/sbin/arp -na $gateway_ip};
	    $mac = $1 if $arp =~ /at\s+([0-9a-zA-Z:]+)/;
	} elsif (m/^$opt_t\s+dev\s+(\S+)\s+src\s+(\S+)/) {
	    ($gateway_ip, $iface, $local_ip) = ('', $1, $2);
            qx{/bin/ping -c 1 -q $opt_t};
            my $arp = qx{/sbin/arp -na $opt_t};
            $mac = $1 if $arp =~ /at\s+([0-9a-zA-Z:]+)/;
	}

    }

    $opt_p = 520 unless $opt_p;

    print STDERR "gateway_ip=$gateway_ip, iface=$iface, local_ip=$local_ip, ";
    print STDERR "remote_ip=$opt_t, mac=$mac, remote_port=$opt_p\n";

    die "ERROR: can not retrieve enoguh network information"
      unless $opt_t && $mac && $local_ip && $iface;

    &mount_configfs;

    mkdir "$HOME/target1" unless -d "$HOME/target1";

    netoops_set("local_ip", $local_ip);
    netoops_set("remote_ip", $opt_t);
    netoops_set("remote_port", $opt_p);
    netoops_set("remote_mac", $mac);
    netoops_set("dev_name", $iface);

    open CF, '>', "/sys/kernel/netoops/netoops_record_oom";
    print CF "1\n";
    close CF;

    open KMSG, '>', '/dev/kmsg';
    print KMSG "--------> enable netoops <-----------\n";
    close KMSG;

    netoops_set("enabled", "1");

    my @dmesg = ();
    foreach (split /\n/, qx{/bin/dmesg}) {
        chomp;
	push @dmesg, $_ if m/netoops/;
        @dmesg =($_) if m/--> enable netoops <--/;
    }

    print STDERR join("\n", @dmesg),"\n";
    print STDERR "--------> dmesg cut here <-----------\n";
}


&main;
