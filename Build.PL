use strict;
use warnings;

use lib 'inc';
use MyBuilder;

use Archive::Any;
use YAML::Any qw/LoadFile/;
use Data::Dumper;
use LWP::Simple;
use File::Copy;
use File::Path qw.remove_tree.;

remove_tree('treetagger');

my $builder = MyBuilder->new(
                             module_name    => 'Lingua::TreeTagger::Installer',
                             dist_abstract  => "Automates TreeTagger installation",
                             dist_author    => q{Alberto Simões <ambs@cpan.org>},
                             license        => 'perl',
                             build_requires => { 'Test::More' => '0.40', },
                             add_to_cleanup => ['Lingua-TreeTagger-Installer-*', 'treetagger'],
);

my $installlibdir =  $builder->install_destination("lib");
my $installbindir =  $builder->install_destination("bin");

my $treelibdir = "$installlibdir/treetagger";
my $treebindir = "$installbindir/treetagger";


my $yaml = LoadFile "config.yaml";
my $platform = install_binary($yaml->{platforms});

$builder->notes('platform' => $platform);

install_tagger_scripts();
install_parameters($yaml->{languages});

process_files($builder,
              bin => $installbindir,
              cmd => $treebindir,
              lib => $treelibdir);

add_custom_installs($builder,
                    sitebin => $installbindir,
                    libdir  => $treelibdir,
                    bindir  => $treebindir);

$builder->create_build_script;


sub install_parameter {
    my $url = shift;

    print "\nFetching language parameter\n($url)\n";
    if ($url =~ m!PT-GZ!) {
        getstore($url, "PT-GZ.tar.gz");
        my $tgz = Archive::Any->new("PT-GZ.tar.gz");
        $tgz->extract("treetagger");
        unlink "PT-GZ.tar.gz";
        for my $f (glob("treetagger/bin/*.perl")) {
            my $t = $f;
            $t =~ s!treetagger/bin!treetagger/cmd!;
            move $f, $t;
            chmod 0755, $t;
        }
    } else {
        my $filename = $url;
        $filename =~ s!^.*/!!;
        getstore($url, $filename);
        $filename =~ m!([a-z]*)\d*-par!;
        my $language = $1;
        my $utf = "";
        $utf = "-utf8" if ($filename =~ m!utf8!);

        print "\nUnzipping to $language$utf.par\n";
        `gunzip -ca $filename > treetagger/lib/$language$utf.par`;
        unlink $filename;
    }
}

sub install_parameters {
    my $languages = shift;
    my $language;
    my $quick_access;

    my $i = 1;
    for my $lang (keys %$languages) {
        my $j = 1;
        for my $opt (keys %{$languages->{$lang}}) {
            $quick_access->{"$i.$j"} = [$languages->{$lang}{$opt}, 
                                        sprintf("%20s (%s)", $lang, $opt)];
            ++$j;
        }
        ++$i;
    }

    do {
        print "\nChoose a language to install or 'exit' to finish\n";

        for my $key (sort {$a <=> $b} keys %$quick_access) {
            printf "  %5s %s\n", $key, $quick_access->{$key}[1];
        }

        $language = Module::Build->prompt("Install language:", "exit");

        if ($language ne "exit") {
            if (exists($quick_access->{$language})) {
                install_parameter($quick_access->{$language}[0]);
                delete($quick_access->{$language});
            } else {
                print "**ERROR** Unknown language"
            }
        }

    } while (%$languages && $language ne "exit");
}

sub install_binary {
    my $platforms = shift;
    my $platform;
    do {
        print "\n**ERROR** Choose one option or use 'exit' to abort\n" if $platform;

        print "Available platforms\n";
        print "  $_\n" for (keys %$platforms);

        $platform = Module::Build->prompt("Choose your platform", "linux");

    } until (exists($platforms->{$platform}) || $platform eq "exit");

    print "**ABORTED**\n" and exit if $platform eq "exit";

    my $url = $platforms->{$platform};

    mkdir "treetagger";

    print "\nFetching Tree-Tagger binary\n($url)\n";
    getstore($url, "treetagger.tar.gz");
    die "Could not download $url!\n" unless -f "treetagger.tar.gz";

    print "Unwrapping tarball\n";
    my $tgz = Archive::Any->new("treetagger.tar.gz");
    $tgz->extract("treetagger");
    unlink "treetagger.tar.gz";

    return $platform;
}


sub install_tagger_scripts {
    my $url = "ftp://ftp.ims.uni-stuttgart.de/pub/corpora/tagger-scripts.tar.gz";
    print "\nFetching Tree-Tagger scripts\n($url)\n";
    getstore($url, "tagger-scripts.tar.gz");

    print "Unwrapping tarball\n";
    my $tgz = Archive::Any->new("tagger-scripts.tar.gz");
    $tgz->extract("treetagger");
    unlink "tagger-scripts.tar.gz";
}


sub process_files {
    my ($builder, %paths) = @_;

    $builder->fix_shebang_line(glob("treetagger/cmd/*.perl"));

    for my $file (glob("treetagger/cmd/*")) {
        my $contents;
        {
            local $/ = undef;
            open F, "$file" or die;
            $contents = <F>;
            close F;
            $contents =~ s/BIN=.*/BIN='$paths{bin}'/;
            $contents =~ s/CMD=.*/CMD='$paths{cmd}'/;
            $contents =~ s/LIB=.*/LIB='$paths{lib}'/;
            open F, ">$file" or die;
            print F $contents;
            close F;
        }
    }
    for my $file (glob("treetagger/cmd/tree-tagger-*")) {
        move( $file, "treetagger/bin" );
    }
}

sub add_custom_installs {
    my $builder = shift;
    my %paths = @_;

    # Tell Module::Build there's two new types of installs.
    $builder->add_build_element('treelib');
    $builder->add_build_element('treebin');
    $builder->add_build_element('sitebin');

    # And where to install them.
    $builder->install_path( treebin => $paths{bindir} );
    $builder->install_path( treelib => $paths{libdir} );
    $builder->install_path( sitebin => $paths{sitebin});
}

