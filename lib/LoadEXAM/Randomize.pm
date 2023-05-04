package LoadEXAM::Randomize 0.000001;

use v5.30.3;
use warnings;
use experimental 'signatures';
use LoadEXAM::Grammar;
use List::Util qw(shuffle);
use POSIX;

use Exporter 'import';
our @EXPORT = qw< randomize >;

#reads questions from exam, removes checkmark and then shuffles the answers per question
#generates new file with format YYYYMMDD-HHMMSS-<$path>
sub randomize( $filehandler, $path ){
		
		# Open exam exam master file, read-only
		my $exam = $filehandler;
		
		# Parse Examfile
		my $exam_ref = load_exam( $exam );
		
		my $time = strftime "%Y%m%d-%H%M%S", localtime time;
		
		open( my $new_exam, ">", "$time-$path" );
		
		print $new_exam $exam_ref->{preface};
		
		foreach my $section ( @{ $exam_ref->{Q_and_A} } )
		{
		    print $new_exam "\n";
		
		    print $new_exam "$section->{question}->{number}. $section->{question}->{text} \n";
		
		    my @answers = @{ $section->{answers} };
		
		    @answers = shuffle @answers;
		
		    for my $answer (@answers){
		        print $new_exam "\t[ ] $answer->{text}" ;
		    }
		
		    print $new_exam "\n";
		    print $new_exam "________________________________________________________________________________";
		    print $new_exam "\n";
		    print $new_exam "\n";
		}
}
