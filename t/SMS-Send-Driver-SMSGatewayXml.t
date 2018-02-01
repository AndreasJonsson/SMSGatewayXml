# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl SMS-Send-Driver-SMSGatewayXml.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use utf8;
use strict;
use warnings;

use Test::More tests => 10;
BEGIN { use_ok('SMS::Send::Driver::SMSGatewayXml') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use SMS::Send;
use DateTime;
use Encode;
use Encode::Encoder;

binmode STDERR, ':encoding(utf8)';

my $sender = SMS::Send->new(
    'Driver::SMSGatewayXml',
    _login    => 'myname',
    _password => 'mypassword',
    _sender => 'sender'
    );


my $sendDt = DateTime->now;

my $text = "text \x{e5}\x{e4}\x{f6}\x{c5}\x{c4}\x{d6}\x{3042}\x{304a}\x{3046}\x{3048}\x{3044}";

my $xml = $sender->build_xml({
    to => '+46123456789',
    text => $text,
    dt => $sendDt,
});

my $parser = XML::LibXML->new(no_blanks => 1, no_cdata => 0, encoding => 'utf8');

#$xml = Encode::Encoder->new($xml, '')->utf8;

my $dom = $parser->load_xml(string => $xml);

ok(defined($dom), 'Parse the resulting XML of SMS::Send::Driver::SMSGatewayXml::build_xml');
is(scalar(@{$dom->getElementsByTagName('send_date')}), 1, 'One send_date element');
my $sendDate =  ${$dom->getElementsByTagName('send_date')}[0];
is(scalar(@{$dom->getElementsByTagName('send_time')}), 1, 'One send_time element');
my $sendTime =  ${$dom->getElementsByTagName('send_time')}[0];

my $expectedXml = <<EOXML;
<?xml version="1.0" ?>
<sms-teknik>
<operationtype>5</operationtype>
<flash>0</flash>
<multisms>1</multisms>
<maxmultisms>6</maxmultisms>
<ttl>0</ttl>
<customid></customid>
<compresstext>0</compresstext>
<send_date>2009-05-24</send_date>
<send_time>10:30:00</send_time>
<udh></udh>
<udmessage>text \x{e5}\x{e4}\x{f6}\x{c5}\x{c4}\x{d6}\x{3042}\x{304a}\x{3046}\x{3048}\x{3044}</udmessage>
<smssender>sender</smssender>
<deliverystatustype>0</deliverystatustype>
<deliverystatusaddress></deliverystatusaddress>
<usereplynumber>0</usereplynumber>
<usereplyforwardtype>0</usereplyforwardtype>
<usereplyforwardurl></usereplyforwardurl>
<usereplycustomid></usereplycustomid>
<usereplysmp>0</usereplysmp>
<usee164>0</usee164>
<items>
            <recipient>
                    <nr>+46123456789</nr>
            </recipient>
</items>
</sms-teknik> 
EOXML
my $expectedDom = $parser->load_xml(string => $expectedXml);

ok(defined($expectedDom), 'Parse the expected XML');
is(scalar(@{$expectedDom->getElementsByTagName('send_date')}), 1, 'One expected send_date element');
my $expectedSendDate =  ${$expectedDom->getElementsByTagName('send_date')}[0];
is(scalar(@{$expectedDom->getElementsByTagName('send_time')}), 1, 'One expected send_time element');
my $expectedSendTime =  ${$expectedDom->getElementsByTagName('send_time')}[0];

$expectedSendDate->removeChildNodes();
$expectedSendTime->removeChildNodes();

$expectedSendDate->appendText($sendDt->strftime('%F'));
$expectedSendTime->appendText($sendDt->strftime('%T'));

my $result = $dom->toString();
my $expected = $expectedDom->toString();

#utf8::decode($result);
#utf8::decode($expected);

is($result, $expected, 'Build xml');

is(SMS::Send::Driver::SMSGatewayXml::normalize_phone_number('(070) 123 45 67'), '+46701234567');

eval { SMS::Send::Driver::SMSGatewayXml::normalize_phone_number('112'); };
ok ($@ =~ /^Invalid phone number '112'/);

