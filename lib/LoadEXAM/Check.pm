package LoadEXAM::Check 0.000001;

use v5.30.3;
use warnings;
use experimental 'signatures';
use POSIX;
use Lingua::StopWords qw( getStopWords );
use Text::Levenshtein qw(distance);
use List::Util qw(sum max min);

use LoadEXAM::Grammar 'load_exam';

use Exporter 'import';
#our @EXPORT = qw< check getCorrectAnswer printReport >;
our @EXPORT = qw< check >;
our $stopwords = getStopWords('en');

#checks each answer in each file from the args based on the master_file's answers
sub check( $filehandler, @examfiles ){
    # Open exam exam master file, read-only
    #open( my $master_exam_file, "<", $ARGV[0] );
    my $master_exam_file = $filehandler;
    
    # Parse Examfile
    my $exam_master = load_exam( $master_exam_file );

    #variables used for statistics and report
    my %totalAnswerCountPerFile;
    my %correctAnswerCountPerFile;
    
    #loop throught exam_files in ARGV starting from 2, ARGV[1] contains master_file
    for(my $i = 2; $i <= $#ARGV; $i++){
        my $file_name = $ARGV[$i];
        open( my $exam_file, "<", $file_name );
        my $exam = load_exam( $exam_file );

        my $correct_answers_count = 0;
        my $total_answered = 0;
        my $total_answers_count = 0;

        foreach my $section ( @{ $exam->{Q_and_A} } )
        {
            my @answers = @{ $section->{answers} };
            my $correct_answer = getCorrectAnswer($exam_master, $section->{question}->{text});
            my $answer_count = 0;
            my $correct_answer_found;

            for my $answer (@answers){
                if ($answer->{checkbox} =~ m/X/ || $answer->{checkbox} =~ m/x/) {
                    $answer_count++;

                    #breaks loop if there is more than 1 selected answer
                    if($answer_count > 1){
                        last;
                    }

                    if(compareStrings($correct_answer, $answer->{text}) != -1){
                        $correct_answer_found = 1;
                    }
                }
            }

            $total_answers_count++;

            #only count correct answer if there is only one answer
            if($answer_count == 1 && $correct_answer_found){
                $correct_answers_count++;
                $total_answered++;
            }elsif($answer_count == 1 && !$correct_answer_found){
                $total_answered++;
            }
        }

        $totalAnswerCountPerFile{$file_name} = $total_answered;

        $correctAnswerCountPerFile{$file_name} = $correct_answers_count;

        print "$file_name: $correct_answers_count/$total_answers_count\n";
        close($exam_file);
    }

    printStatistics(\%totalAnswerCountPerFile, \%correctAnswerCountPerFile);
    
    print "\n";
    
    for(my $i = 2; $i <= $#ARGV; $i++){
        my $file_name = $ARGV[$i];
        open( my $exam_file, "<", $file_name );
        my $exam = load_exam( $exam_file );
        printReport($exam_master, $exam, $file_name);
        close($exam_file);
    }

    printBelowExpectations(\%totalAnswerCountPerFile, \%correctAnswerCountPerFile);
}
		
#returns the correct answer from $question in the $hashref file
sub getCorrectAnswer($hashref, $question ) {
    foreach my $master_section ( @{ $hashref->{Q_and_A} } )
    {
        if(compareStrings($master_section->{question}->{text}, $question) != -1){
            my @answers = @{ $master_section->{answers} };

            for my $answer (@answers){
                if ($answer->{checkbox} =~ m/X/) {
                    return $answer->{text};
                }
            }
        }
    }
}

#Reports missing Answers and Questions
#Reports slightly changed but still correct Questions and Answers
sub printReport( $master_exam, $exam, $filename ) {

    #boolean value if the fileName has been written, so it is only written once if necessary
    my $fileNameWritten = undef;

    #loop through all sections (containing questions and answers) of master_exam
    foreach my $master_section ( @{ $master_exam->{Q_and_A} } )
    {
        my $master_question = $master_section->{question}->{text};
        my @master_answers = @{ $master_section->{answers} };
        my $question_found = undef;

        #loop through all sections (containing questions and answers) of exam
        foreach my $section ( @{ $exam->{Q_and_A} }){
            my $question = $section->{question}->{text};
            my $distance_question = compareStrings($master_question, $question);

            if($distance_question == -1){
                next;
            }

            $question_found = 1;
            my @answers = @{ $section->{answers} };

            #loop through all answers of master_question
            foreach my $master_answer ( @master_answers){
                my $answer_found = 0;
                my $final_distance = -1;
                my $correct_answer = "";
                
                #loop through all answers of exam_question and compares it to master_question
                foreach my $answer ( @answers ){
                    my $distance_answer = compareStrings($master_answer->{text}, $answer->{text});

                    if($distance_answer == -1){
                        next;
                    }

                    $answer_found = 1;

                    #store answer with lowest distance, because lowest distance means most correct answer
                    if($distance_answer < $final_distance || $final_distance == -1){
                        $final_distance = $distance_answer;
                        $correct_answer = $answer;
                    }

                    if($distance_answer == 0){
                        last;
                    }
                }

                if(!$answer_found){
                    if(!$fileNameWritten){
                        $fileNameWritten = 1;
                        print "$filename\n";
                    }

                    print "\tMissing answer: $master_answer->{text}";
                } elsif($final_distance && $final_distance > 0){
                    if(!$fileNameWritten){
                        $fileNameWritten = 1;
                        print "$filename\n";
                    }

                    print "\tMissing answer:\t$master_answer->{text}";
                    print "\tUsed this instead:\t $correct_answer->{text}";
                }
            }

            if($distance_question > 0){
                if(!$fileNameWritten){
                    $fileNameWritten = 1;
                    print "$filename\n";
                }

                print "\tMissing question:\t$master_question";
                print "\tUsed this instead:\t$question";
            }

            last;
        }

        if(!$question_found){
            if(!$fileNameWritten){
                $fileNameWritten = 1;
                print "$filename\n";
            }
            print "\tMissing question: $master_question";
        }
    }
}

#Compares two normalized strings, returns true if edit-distance is less than or equals 10% of length of first string
sub compareStrings {
    my $distance = distance(normalize($_[0]), normalize($_[1]));
    if($distance <= length($_[0])/10){
        return $distance;
    }

    return -1;
}

#normalizes string
# -string to lowercase
# -removes stop-words
# -sepeartes each string with one whitespace
# -removes whitespaces before or after string
sub normalize {
    my $string = $_[0];
    $string = lc($string);
    my @words = split(" ", $string);
    $string = join ' ', grep { !$stopwords->{$_} } @words;

    return $string;
}

#Prints Avg of Total and Correct Answers, Max of Total and Correct Answers and Min of Total and Correct Answers
sub printStatistics {
    my %totalAnswerCountPerFile = %{$_[0]};
    my %correctAnswerCountPerFile = %{$_[1]};

    my $sumTotal = sum values %totalAnswerCountPerFile;
    my $keysTotal = keys %totalAnswerCountPerFile;
    my $avgTotal = int $sumTotal/$keysTotal;
    my $highestTotal = max values %totalAnswerCountPerFile;
    my $lowestTotal = min values %totalAnswerCountPerFile;

    my $sumCorrect = sum values %correctAnswerCountPerFile;
    my $keysCorrect = keys %correctAnswerCountPerFile;
    my $avgCorrect = int $sumCorrect/$keysCorrect;
    my $highestCorrect = max values %correctAnswerCountPerFile;
    my $lowestCorrect = min values %correctAnswerCountPerFile;

    my $countHighestTotal = 0;
    my $countLowestTotal = 0;
    foreach my $val (values %totalAnswerCountPerFile) {
        if($val == $highestTotal){
            $countHighestTotal++;
        } elsif ($val == $lowestTotal){
            $countLowestTotal++;
        }
    };

    my $countLowestCorrect = 0;
    my $countHighestCorrect;
    foreach my $val (values %correctAnswerCountPerFile) {
        if($val == $highestCorrect){
            $countHighestCorrect++;
        } elsif ($val == $lowestCorrect){
            $countLowestCorrect++;
        }
    };

    print "\n";
    print "Average number of questions answered..... $avgTotal\n";
    print "\tMinimum.... $lowestTotal ($countLowestTotal answered)\n";
    print "\tMaximum.... $highestTotal ($countHighestTotal answered)\n";

    print "Average number of correct answered..... $avgCorrect\n";
    print "\tMinimum.... $lowestCorrect ($countLowestCorrect answered)\n";
    print "\tMaximum.... $highestCorrect ($countHighestCorrect answered)\n";
}

#Print exams where less than 50% of the answers are correct
sub printBelowExpectations {
    my %totalAnswerCountPerFile = %{$_[0]};
    my %correctAnswerCountPerFile = %{$_[1]};
    my $belowExpectationsPrinted = undef;

    foreach my $key (keys %correctAnswerCountPerFile) {
        if($correctAnswerCountPerFile{$key} < $totalAnswerCountPerFile{$key}/2) {
            if(!$belowExpectationsPrinted){
                $belowExpectationsPrinted = 1;
                print "Results below expectation:\n";
            }
            print "\t$key....$correctAnswerCountPerFile{$key}/$totalAnswerCountPerFile{$key} (score < 50%)\n";
        }
    }
}
