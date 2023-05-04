#! /usr/bin/env perl

use v5.30.3;
use warnings;
use experimental 'signatures';

use lib './lib';
use LoadEXAM::Check;
use LoadEXAM::Randomize;

if( $ARGV[0] eq "--randomize" ){
		if ( !$ARGV[1] ) { print "Missing argument: exam master file\n"; }
		else { 
				my $masterfile = $ARGV[1];
				open( my $fh, "<", $masterfile);
				randomize( $fh, $masterfile ); }
}

if( $ARGV[0] eq "--check" ){
		if ( !$ARGV[1] ) { print "Missing argument: exam file\n"; }
		elsif ( !$ARGV[2] ) { print "Missing argument: exam file\n"; }
		else { 
				my $examfile = $ARGV[1];
				open( my $fh, "<", $examfile );
				check( $fh, $examfile ); }
}
