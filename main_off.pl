#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use YAML::XS;

use lib 'lib/';
use MySacloud;

my ($api_yml, $server_yml) = ("","");

GetOptions(
  "api=s" => \$api_yml,
  "server=s" => \$server_yml,
) or die 'invalid settings';

die 'cant read api.yaml' unless -r $api_yml;
die 'cant read server.yaml' unless -r $server_yml;

my $config = YAML::XS::LoadFile($api_yml);
my $service = YAML::XS::LoadFile($server_yml);

my $agent = MySacloud->new(
    token => $config->{sakura_cloud}{token},
    secret => $config->{sakura_cloud}{secret},
    zone => $config->{sakura_cloud}{zone},
);

my %disks = %{$service->{disks}};

foreach my $host (sort keys %disks) {
    printf STDERR "%s: ", $host;
#   warn Dumper $disks{$host};

    # check disk status
    my $status = $agent->disk_status(
        disk_id => $disks{$host},
    );
#   warn Dumper $status->{Disk}{Server};

    # no connect disk to server.
    unless ($status->{Disk}{Server}) {
        printf STDERR "disk: $disks{$host} is no connected/halted.\n"; # XXX
        next;
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

    print STDERR "\n";

}

__END__

