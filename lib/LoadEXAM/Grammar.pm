package LoadEXAM::Grammar 0.001;

use v5.30.3;
use warnings;
use experimental 'signatures';
use Regexp::Grammars;

use Exporter 'import';
our @EXPORT = qw< load_exam >;

my $EXAM_GRAMMAR = qr{

    <exam>

    <nocontext:> # This turns off the feature of remembered the text
                 # that each subrule matched (so we don't clutter the data structure).

    # Rules allow whitespace between their components...
    <rule: exam>
        <preface>
        <[Q_and_A]>+  %  <.separator>
        # The square brackets around 'Q_and_A' mean: capture all repetitions into an array
        # The % syntax means: "...separated by..."
        # The dot (.) before 'separator' means: do not include this in the data structure


    # Tokens match exactly (they don't skip over whitespace between components)...
    <token: preface>
        .*?  <.separator>

    <token: separator>
        ^ \h* _+ \h* \n

    <rule: Q_and_A>
        <question>
        <[answers]>+

    <token: question>
        ^ \h* <number> \. \h* <text>

    <token: answers>
        ^ \h* <checkbox> \h* <text>

    <token: number>
        \d+

    <token: checkbox>
        \[  [^]\v]*  \]

    <token: text>
        \N* \n                              # The rest of the current line
        (?: <!answers> ^ \N* \S \N* \n )*   # ...plus any subsequent non-blank lines

        # The exclamation mark (!) before 'answers' means: whatever follows must NOT match an <answers>

}xms;

sub load_exam($fh) {
		# Load exam file as string to variable
		my $exam_content = do { local $/; readline($fh); };
		
		# Match file content with Grammar defined in $EXAM_GRAMMAR	
		if( $exam_content =~ $EXAM_GRAMMAR ) {
				return $/{exam};
		}
		else {
				return undef;
		}
}

#1;
