use strict;
use warnings;
use utf8;
use Test::More;

use YAML::XS;
my $config = YAML::XS::LoadFile("etc/api.yml");

use lib 'lib/';

plan(tests => 6);

use_ok('MySacloud');

my $agent = MySacloud->new(
    token => $config->{sakura_cloud}{token},
    secret => $config->{sakura_cloud}{secret},
    zone => "tk1v",
);

my $response = $agent->create(
    name => "agent test1",
    switch => "shared",
    plan => 12006,
);

ok($response->{Server}{ServerPlan}{ID} == 12006, 'create');

my $response2 = $agent->attach(
    server_id => $response->{Server}{ID},
    disk_id => 112900067056,
);
ok($response2->{Success}, 'attach');

my $response3 = $agent->poweron(
    server_id => $response->{Server}{ID},
);
ok($response3->{Success}, 'poweron');

my $response4 = $agent->poweroff(
    server_id => $response->{Server}{ID},
);
ok($response4->{Success}, 'poweroff');

my $response5 = $agent->destroy(
    server_id => $response->{Server}{ID},
);
ok($response5->{Success}, 'destroy');

