requires 'LWP::UserAgent';
requires 'YAML::XS';
requires 'JSON::XS';
requires 'Sub::Retry';

on 'test' => sub {
    requires 'Test::More';
};
