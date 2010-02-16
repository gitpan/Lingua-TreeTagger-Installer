package MyBuilder;

use base 'Module::Build';
use File::Copy;

sub process_treelib_files {
    my $builder = shift;

    my @files = grep { -f $_ }  @{$builder->rscan_dir("treetagger/lib")};
    for my $file (@files) {
        $builder->copy_if_modified( from => $file, to_dir =>  "blib/treelib", flatten => 1 );
    }
}

sub  process_treebin_files {
    my  $builder = shift;

    if ($builder->notes('platform') eq "macosx-intel") {
        my $files = $builder->rscan_dir("extrafiles", qr/\.mac$/);
        for my $file (@$files) {
            my $target = $file;
            $target =~ s!extrafiles!blib/script!;
            $target =~ s!\.mac$!!;
            copy $file, $target;
            chmod 755, $target;
        }
    }

    my @files = grep { -f $_ }  @{$builder->rscan_dir("treetagger/cmd")};
    for my $file (@files) {
        $builder->copy_if_modified(from=>$file, to_dir=>"blib/treebin", flatten => 1 );
    }
}

"troue";
