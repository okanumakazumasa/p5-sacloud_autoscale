use strict;
use warnings;
use utf8;
use Test::More;

use YAML::XS;
my $config = YAML::XS::LoadFile("etc/api.yml");

use lib 'lib/';

plan(tests => 2);

use_ok('MySacloud');

my $agent = MySacloud->new(
    token => $config->{sakura_cloud}{token},
    secret => $config->{sakura_cloud}{secret},
    zone => "tk1v",
);
ok(defined $agent);

