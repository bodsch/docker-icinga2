#!/usr/bin/perl
#
use JSON;
use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
#use utils qw(%ERRORS);
 
my ( $data, $cn, $matchpart, $fingerprint, $signed);
 
#use vars qw($opt_m);
 
#$matchpart = "corp.int";
 
GetOptions (
  "m|match_pattern" => \$matchpart,
) or die("Error parameter -m is missing");
 
$data = doIcingaCaList();
 
foreach $fingerprint ( keys %{$data}) {
    $cn     = $data->{$fingerprint}->{'subject'};
    $signed = $data->{$fingerprint}->{'cert_response'};
    $cn =~ s/CN = //;
 
    if (defined $signed) {
      print "Already signed agent $cn\n";
    } else {
      doMatching($cn,$fingerprint);
    }
 
}
 
sub doMatching {
  my $match = $_[0];
  my $finger = $_[1];
 
  if (grep(/@ARGV/, $match)) {
    my $exec = "icinga2 ca sign " . $finger;
    my $result = qx($exec);
    print "$result";
    print "Signed $cn with fingerprint: $finger \n\n";
  }
  else
  {
    print "not matched CN $cn\n";
  }
}
 
sub doIcingaCaList {
  my $json = `icinga2 ca list --json`;
  my $result = decode_json($json);
  return $result;
 
} 
