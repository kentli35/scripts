#!/usr/bin/perl -w
use Term::ANSIColor qw(:constants);
use File::Spec;
use Smart::Comments;
my $workdir="/var/www/oa";
my $backdir="/var/www";
my $operation="salt -N 'school' cmd.run '/root/ischool.sh -v'";
my $minion_err="error: Your local changes to the following files would be overwritten by merge:";
my $max_err=0;
MAIN: while(1){
    print YELLOW "Start pulling...\n",RESET;
    chomp(@output=`$operation`);
    print CYAN $_."\n\n" foreach @output ,RESET;
    for($i=0;$i<=$#output;$i++){
        if($output[$i] =~ /$minion_err/){
            print RED "Something is screwing us,let's get rid of it...\n", RESET;
            ($err_file = $output[$i+2]) =~ s/(\s)+//;
            ($err_server = $output[$i-2]) =~ s/://;
            $target_file=File::Spec->catfile($workdir,$err_file);
            $backup_file=File::Spec->catfile($backdir,$err_file);
            $result=`salt "$err_server" cmd.run "mv $target_file $backup_file -v" -v`;
            print $result;
            $max_err++;
        }else{
            print YELLOW "Pulling completed...\n";
            last MAIN;
        }
    }
        if($max_err==5){
            print RED "There are only $max_err retries and you've exceeded it ,please check\n", RESET;
            last MAIN;
        }
}

print YELLOW "The website has been updated.\n",RESET;

### $err_file;
### $err_server;
### target_file;
### backup_file;

