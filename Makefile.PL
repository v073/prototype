use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    VERSION             => '0.01',
    MIN_PERL_VERSION    => '5.20.0',
    PREREQ_PM           => {
        'Mojolicious'       => '8.56',
    },
    test                => {TESTS => 't/*.t'},
);
