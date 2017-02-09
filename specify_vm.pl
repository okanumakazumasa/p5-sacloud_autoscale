#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use YAML::XS;

use lib 'lib/';
use MySacloud;

my ($api_yml, $server_yml) = ("", "");
my ($host, $mode);

GetOptions(
  "api=s" => \$api_yml,
  "server=s" => \$server_yml,
  "vm=s" => \$host,
  "power=s" => \$mode,
) or die 'invalid settings';

die 'cant read api.yaml' unless -r $api_yml;
die 'cant read server.yaml' unless -r $server_yml;
die 'need select vm' unless defined $host;
die 'need power on or off' unless defined $mode;

my $config = YAML::XS::LoadFile($api_yml);
my $service = YAML::XS::LoadFile($server_yml);

my $agent = MySacloud->new(
    token => $config->{sakura_cloud}{token},
    secret => $config->{sakura_cloud}{secret},
    zone => $config->{sakura_cloud}{zone},
);

my %disks = %{$service->{disks}};

unless (defined $disks{$host}) {
    die "invalid vm: $host";
}

printf STDERR "%s: ", $host;
#warn Dumper $host;
#warn Dumper $disks{$host};

# check disk status
my $status = $agent->disk_status(
    disk_id => $disks{$host},
);

if ($mode eq "on") {
    if ($status->{Disk}{Server}) {
        print STDERR "disk: $disks{$host} is booted. \n";
        exit 1;
    }

    # create server
    my $server = $agent->create(
        name => $host,
        switch => $service->{switch},
        plan => $service->{plan},
        tags => $service->{tags},
    );
    
    #warn Dumper $server;
    
    my $attach = $agent->attach(
        server_id => $server->{Server}{ID},
        disk_id => $disks{$host},
    );
    
    unless ($attach) {
        print STDERR "cant attach disk\n";
        exit 2;
    }
    
    my $power = $agent->poweron(
        server_id => $server->{Server}{ID},
    );
    
    if ($power->{Success}) {
        print STDERR "ok.";
    } else {
        print STDERR "sakura cloud say booting fail.\n"; # XXX
    }
}

if ($mode eq "off") {
    unless ($status->{Disk}{Server}) {
        printf STDERR "disk: $disks{$host} is no connected/halted.\n"; # XXX
        exit 1;
    }

    my $server_id = $status->{Disk}{Server}{ID};

    if ($status->{Disk}{Server}{Instance}{Status} ne 'down') {
        my $power = $agent->poweroff(
            server_id => $server_id,
        );
        unless ($power) {
            print STDERR " cant shutdown."; # XXX
            next;
        }
    }
    
    my $response = $agent->destroy(
        server_id => $server_id,
    );
#   warn Dumper $response;

    if ($response->{Success}) {
        print STDERR "ok.";
    } else {
        print STDERR "sakura cloud say shutdown fail.\n"; # XXX
    }
}

print STDERR "\n";

__END__

