package MySacloud;

use strict;
use warnings;
use utf8;

use JSON::XS;
use LWP::UserAgent;
use MIME::Base64 qw/encode_base64/;
use Sub::Retry;

sub new {
    my ($class, %opt) = @_;

    foreach (qw/token secret zone/) {
        die "Missing Parameter: $_" unless defined $opt{$_};
    }

    bless \%opt, $class;
}

#
# util
#

sub ua {
    my $self = shift;
    unless (defined $self->{ua}) {
        my $mixed = encode_base64 sprintf '%s:%s', $self->{token}, $self->{secret};
        my $header = HTTP::Headers->new(
            Authorization => "Basic $mixed",
            'Content-Type' => 'application/json',
        );
        $self->{ua} = LWP::UserAgent->new(
            default_headers => $header
        );
    }
    $self->{ua};
}

sub url {
    my ($self, $param) = @_;

    sprintf 'https://secure.sakura.ad.jp/cloud/zone/%s/api/cloud/1.1/%s',
       $self->{zone},
       $param;
}

#
# handle
#

sub create {
    my ($self, %opt) = @_;

    return undef unless defined $opt{name};
    return undef unless defined $opt{switch};
    return undef unless defined $opt{plan};

    # 共有セグメント or スイッチ接続で指定が変わる
    my $switch = 'ID';
    if ($opt{switch} eq 'shared') {
        $switch = 'Scope';
    }

    # タグはARRAYも許容
    my @tags;
    if (defined $opt{tags}) {
        @tags = (ref $opt{tags} eq 'ARRAY') ? $opt{tags} : [ $opt{tags} ];
    }

    my %params = (
        Server => {
            Name => $opt{name},
            ServerPlan => {
                ID => $opt{plan},
            },
            @tags ? (Tags => @tags) : (),
            ConnectedSwitches => [
                { $switch => $opt{switch} }
            ]
        },
        Count => 0
    );
    my $query = encode_json \%params;

    my $url = $self->url('server');
    my $req = HTTP::Request->new(POST => $url);
    $req->content($query);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

sub destroy {
    my ($self, %opt) = @_;

    return undef unless defined $opt{server_id};

    # is it poweroff?
    my $status = $self->detail(%opt);

    if ($status->{Server}{Instance}{Status} eq 'down') {
        return $self->delete(%opt);
    }

    print STDERR "wait down";

    # off するまで待つ
    my $res = retry 20, 3, sub {
        'down';
    }, sub {
        my $status = $self->detail(%opt);
        print STDERR ".";
        $status->{Server}{Instance}{Status} ne 'down';
    };

    print STDERR "\n";
    if ($res eq 'down') {
        return $self->delete(%opt);
    }
    return undef;
}

sub delete {
    my ($self, %opt) = @_;

    return undef unless defined $opt{server_id};

    my $param = sprintf 'server/%d', $opt{server_id};

    my $url = $self->url($param);
    my $req = HTTP::Request->new(DELETE => $url);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

sub detail {
    my ($self, %opt) = @_;

    return undef unless defined $opt{server_id};

    my $param = sprintf 'server/%d', $opt{server_id};

    my $url = $self->url($param);
    my $req = HTTP::Request->new(GET => $url);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

#
# boot/shutdown
#

sub _power {
    my ($self, %opt) = @_;

    return undef unless defined $opt{server_id};
    return undef unless defined $opt{method};

    my $param = sprintf 'server/%d/power', $opt{server_id};

    my $url = $self->url($param);
    my $req = HTTP::Request->new($opt{method} => $url);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

sub poweron {
    shift->_power(@_, method => 'PUT');
}

sub poweroff {
    shift->_power(@_, method => 'DELETE');
}

#
# disk
#

sub attach {
    my ($self, %opt) = @_;

    return undef unless defined $opt{disk_id};
    return undef unless defined $opt{server_id};

    # connected server ?
    my $status = $self->disk_status(disk_id => $opt{disk_id});
    if ($status->{Disk}{Server}) {
        return undef;
    }

    my $param = sprintf 'disk/%d/to/server/%d', $opt{disk_id}, $opt{server_id};

    my $url = $self->url($param);
    my $req = HTTP::Request->new(PUT => $url);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

sub disk_status {
    my ($self, %opt) = @_;

    return undef unless defined $opt{disk_id};

    my $param = sprintf 'disk/%d', $opt{disk_id};

    my $url = $self->url($param);
    my $req = HTTP::Request->new(GET => $url);
    my $res = $self->ua->request($req);

    if ($res->is_success) {
        return decode_json $res->content;
    }
    return undef;
}

1;

