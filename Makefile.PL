use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    VERSION             => '0.01',
    MIN_PERL_VERSION    => '5.20.0',
    PREREQ_PM           => {
        'DBD::SQLite'                   => '1.64',
        'DBIx::Class'                   => '0.08',
        'DBIx::Class::Schema::Loader'   => '0.07',
        'Mojolicious'                   => '8.56',
    },
);
