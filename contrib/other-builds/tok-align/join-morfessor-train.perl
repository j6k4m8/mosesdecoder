#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename;

my $MOSES_DIR = $ARGV[0];
my $INPUT_EXT = $ARGV[1];
my $OUTPUT_EXT = $ARGV[2];
my $OUT_PATH = $ARGV[3];

my $OUT_DIR = "$OUT_PATH.model";

my ($cmd, $cmd2);
$cmd = "mkdir -p $OUT_DIR";
safesystem($cmd);

# data files
my $numFiles = scalar(@ARGV);
$numFiles = ($numFiles - 4) / 2;

$cmd = "cat ";
$cmd2 = "cat ";
for (my $i = 0; $i < $numFiles; ++$i) {
  $cmd .= $ARGV[$i + 4] .".$OUTPUT_EXT ";
  $cmd2 .= $ARGV[$i + 4 + $numFiles] .".$OUTPUT_EXT ";
}

$cmd .= "> $OUT_DIR/corpus.tgt";
$cmd2 .="> $OUT_DIR/corpus.src";
safesystem($cmd);
safesystem($cmd2);

Train("$OUT_DIR/corpus", "src", "tgt", $OUT_PATH, $OUT_DIR);

#############################################                                                                                                                                                                                    
sub Train
{
    my $CORPUS = shift;
    my $INPUT = shift;
    my $OUTPUT = shift;
    my $OUT_PATH = shift;
    my $OUT_DIR = shift;

    my $cmd;

    $cmd = "$MOSES_DIR/bin/lmplz -S 5% -o 5 -T $OUT_DIR < $CORPUS.$OUTPUT > $OUT_DIR/lm";
    safesystem($cmd);

    $cmd = "$MOSES_DIR/bin/build_binary $OUT_DIR/lm $OUT_DIR/lm.kenlm";
    safesystem($cmd);

    $cmd = "$MOSES_DIR/contrib/other-builds/tok-align/tok-align $CORPUS.$INPUT $CORPUS.$OUTPUT  > $OUT_DIR/align.grow-diag-final-and";
    safesystem($cmd);

    $cmd = "$MOSES_DIR/scripts/training/train-model.perl -sort-buffer-size 1G -sort-batch-size 253 -sort-compress pigz -dont-zip -first-step 4 -last-step 9  -f src -e tgt -alignment grow-diag-final-and -max-phrase-length 5  -score-options ' --GoodTuring' -corpus $CORPUS -alignment-file $OUT_DIR/align -extract-file $OUT_DIR/extract -lexical-file $OUT_DIR/lex -phrase-translation-table $OUT_DIR/phrase-table --lm 0:5:$OUT_DIR/lm.kenlm -config $OUT_DIR/moses.ini";
    safesystem($cmd);

    $cmd = "$MOSES_DIR/scripts/training/binarize-model.perl $OUT_DIR/moses.ini $OUT_PATH";
    safesystem($cmd);

}


sub safesystem {
    print STDERR "Executing: @_\n";
    system(@_);
    if ($? == -1) {
	print STDERR "Failed to execute: @_\n  $!\n";
	exit(1);
    }
    elsif ($? & 127) {
      printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
      ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
	my $exitcode = $? >> 8;
	print STDERR "Exit code: $exitcode\n" if $exitcode;
	return ! $exitcode;
    }
}

