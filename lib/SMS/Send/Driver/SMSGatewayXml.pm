package SMS::Send::Driver::SMSGatewayXml;

use strict;
use warnings;

use XML::LibXML;
use HTTP::Tiny;
use DateTime;
use Encode;
use Carp;
use URI;
use utf8;

use base 'SMS::Send::Driver';

our $VERSION = '0.01';

use constant {
    DEFAULT_SERVICE_URL => "https://www.smsteknik.se/Member/SMSConnectDirect/SendSMSv3.asp"
};

#
# Operation type
#
use constant {
    OT_TEXT => 0,
    OT_WAP_PUSH => 1,
    OT_VCARD => 2,
    OT_VCALENDAR => 3,
    OT_BINARY => 4,
    OT_UNICODE => 5,
    };

#
# Flash
#
use constant {
    NORMAL_MESSAGE => 0,
    FLASH_MESSAGE => 1
    };

#
# Delivery status type
#
use constant {
    DST_OFF => 0,
    DST_EMAIL => 1,
    DST_GET => 2,
    DST_POST => 3,
    DST_XML => 4
   };

#
# Use reply forward type
#
use constant {
    URFT_OFF => 0,
    URFT_EMAIL => 1,
    URFT_GET => 2,
    URFT_POST => 3,
    URFT_XML => 4
    };

#
# Number check
#
use constant {
    NC_NO_CHECK => 0,
    NC_CHECK => 1
};

sub new {
    my ($class, %args) = @_;

    my $uri = URI->new(defined($args{_url}) ? $args{_url} : DEFAULT_SERVICE_URL);

    die "No valid url!" unless defined($uri);

    my $self = bless {
	uri => $uri,
	login => $args{_login},
	password => $args{_password},
	company => $args{_company},
	operationtype => OT_TEXT,
	flash => NORMAL_MESSAGE,
	multisms => 1,
	maxmultisms => 6,
	ttl => 0,
	customid => '',
	compresstext => 0,
	deliverystatustype => DST_OFF,
	udh => '',
	usereplynumber => 0,
	usereplyforwardtype => URFT_OFF,
	usereplysmp => 0,
	smssender => defined($args{_sender}) ? $args{_sender} : '',
	send_time => sub {
	    my ($ctx) = @_;
	    return $ctx->{dt}->strftime('%T');
	},
	send_date => sub {
	    my ($ctx) = @_;
	    return $ctx->{dt}->strftime('%F');
	},
	udmessage => sub {
	    my ($ctx) = @_;
	    my $latin1;
	    my $utf8;
	    eval {
		$latin1 = Encode::Encoder->new($ctx->{text})->iso_8859_1;
		$utf8 = Encode::Encoder->new($latin1)->utf8;
	    };
	    my $text;
	    if ($@) {
		set_unicode($ctx);
		$text = $ctx->{doc}->createTextNode($ctx->{text});
	    } else {
		$text = $ctx->{doc}->createTextNode($utf8);
	    }
	    return $text;
	},
	usee164 => 0,
	items => sub {
	    my ($ctx) = @_;
	    my $items = $ctx->{doc}->createElement('items');
	    my $recipient = $ctx->{doc}->createElement('recipient');
	    my $nr = $ctx->{doc}->createElement('nr');
	    $nr->appendText($ctx->{to});
	    $recipient->addChild($nr);
	    $items->addChild($recipient);
	    return $items;
	}
    };
}

sub send_sms {
    my ($self, %args) = @_;

    my $http = HTTP::Tiny->new(verify_SSL => 1);

    my $to;
    eval { $to = normalize_phone_number( $args{to} ); };
    if ($@) {
	return 0;
    }

    my $ctx = {
	dt => DateTime->now,
	to => $to,
	text => $args{text}
    };

    my $xml = $self->build_xml($ctx);

    utf8::decode($self->{company});
    utf8::decode($self->{login});
    utf8::decode($self->{password});

    my $data = {
	id => $self->{company},
	user => $self->{login},
	pass => $self->{password}
    };

    my $uri = $self->{uri}->clone();
    $uri->query_form($data);

    my $resp = $http->request('POST', $uri->as_string,
			      {
				  content => $xml,
				  "content-type" => "application/x-www-form-urlencoded"
			      });

    return $resp->{success};
}

sub build_xml {
    my ($self, $ctx) = @_;

    my $doc = XML::LibXML->createDocument();
    my $root = $doc->createElement('sms-teknik');
    $doc->setDocumentElement($root);

    $ctx->{doc} = $doc;

    foreach my $n (
	'operationtype',
	'flash',
	'multisms',
	'maxmultisms',
	'ttl',
	'customid',
	'compresstext',
	'send_date',
	'send_time',
	'udh',
	'udmessage',
	'smssender',
	'deliverystatustype',
	'deliverystatusaddress',
	'usereplynumber',
	'usereplyforwardtype',
	'usereplyforwardurl',
	'usereplycustomid',
	'usereplysmp',
	'usee164',
	'items' ) {

	my $c = $self->get_parameter($n, $ctx);
	if (UNIVERSAL::isa($c, 'XML::LibXML::Element')) {
	    $root->appendChild($c);
	} else {
	    my $e = $doc->createElement($n);
	    $root->addChild($e);
	    $e->appendText($c);
	}

    }
    my $xml = $doc->toString(0);

    return $xml;
}

sub get_parameter {
    my ($self, $n, $ctx) = @_;

    my $p = $self->{$n};
    if (defined $p) {
	if (UNIVERSAL::isa($p, 'CODE')) {
	    return $p->($ctx);
	}
	return $p;
    }
    return '';
}

sub set_unicode {
    my $ctx = shift;

    my @ot = $ctx->{doc}->getElementsByTagName('operationtype');

    if (scalar(@ot) == 0) {
	@ot = ( $ctx->{doc}->createElement('operationtype') );
	map { $ctx->{doc}->documentElement->appendChild($_) } @ot;
    }

    map {
	$_->removeChildNodes();
	$_->appendText( OT_UNICODE );
    } @ot;
    
}

sub normalize_phone_number {
    my $nr = shift;

    $_ = $nr;
    s/[- \/\\\(\)\[\]]//g;
    s/^(\+\+)|(\+?00)/+/;
    s/^0/+46/;

    croak "Invalid phone number '$nr'" unless /^\+\d*$/;

    return $_;
}
    
1;
__END__

=head1 NAME

SMS::Send::Driver::SMSGatewayXml - SMS::Send::Driver for Smsteknik's SMS Gateway XML API.

=head1 SYNOPSIS

  use SMS::Send::Driver::SMSGatewayXml;

  my $sender = SMS::Send->new(
    'Driver::SMSGatewayXml',
    _company => 'company'
    _login    => 'myname',
    _password => 'mypassword',
    _sender => 'optional sender string',
  );

  $sender->send_sms(to => '+46XXXXXXXXXX',
                    text => 'text message');

=head1 DESCRIPTION

=head1 AUTHOR

Andreas Jonsson, E<lt>andreas.jonsson@kreablo.se<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Andreas Jonsson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.26.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
