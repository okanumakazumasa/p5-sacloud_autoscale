#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use YAML::XS;

use lib 'lib/';
use MySacloud;

my ($api_yml, $server_yml, $machine_count) = ("","",0);

GetOptions(
  "api=s" => \$api_yml,
  "server=s" => \$server_yml,
  "count=i" => \$machine_count,
) or die 'invalid settings';

die 'cant read api.yaml' unless -r $api_yml;
die 'cant read server.yaml' unless -r $server_yml;
die 'need machine count' if $machine_count <= 0;

warn $api_yml;
warn $server_yml;
warn $machine_count;

my $config = YAML::XS::LoadFile($api_yml);

my $agent = MySacloud->new(
    token => $config->{sakura_cloud}{token},
    secret => $config->{sakura_cloud}{secret},
    zone => $config->{sakura_cloud}{zone},
);

#my $responsed = $agent->disk_status(
#    disk_id => 112900067056,
#);
#warn Dumper $responsed;

my $response = $agent->create(
    name => "agent test1",
    switch => "shared",
    plan => 12006,
);

warn Dumper $response;

my $response2 = $agent->attach(
    server_id => $response->{Server}{ID},
    disk_id => 112900067056,
);
warn Dumper $response2;

die "cant attach disk" unless $response2;

my $response3 = $agent->poweron(
    server_id => $response->{Server}{ID},
);
warn Dumper $response3;


__END__


my $response = $agent->poweroff(
    server_id => 112900067307
);
warn Dumper $response;

my $response2 = $agent->destroy(
    server_id => 112900067307
);
warn Dumper $response2;

