use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'REF';

sub GOOD_VALUES {
    [], {}, \*STDIN, qr{}, \1, sub{},
    Class::Base->new(),
    Class::NoOverload->new(),
    Class::WithOverload->new(),
}

sub BAD_VALUES  {
    undef,
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    -10.0, -1.0, 0.0, 1.0, 7.0, 99.0,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    q{}, q{string},
    v1, v1.2, v1.2.3,
    *STDIN,
}


use Data::Checks;


# Test assignment to scalars...

my    $my_scalar    :of(REF) = \0;
our   $our_scalar   :of(REF) = \0;
state $state_scalar :of(REF) = \0;

# Variables have to be initialized with something that passes the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    OKAY { my $var    = $good_value }   "   my scalar = $good_value_str";
    OKAY { our $var   = $good_value }   "  our scalar = $good_value_str";
    OKAY { state $var = $good_value }   "state scalar = $good_value_str";
}

# Implicit undef DOESN'T pass the REF check...
# (Note: can't check uninitialized our variable because that fails at compile-time)
FAIL_ON_INIT { my $uninitialized :of(REF)    }    'uninitialized my scalar';
FAIL_ON_INIT { state $uninitialized :of(REF) }    'uninitialized state scalar';

# Other explicit initializer values also don't pass the REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_INIT { my $uninitialized :of(REF)    = $bad_value }  "   my scalar = $bad_value_str";
    FAIL_ON_INIT { our $uninitialized :of(REF)   = $bad_value }  "  our scalar = $bad_value_str";
    FAIL_ON_INIT { state $uninitialized :of(REF) = $bad_value }  "state scalar = $bad_value_str";
}

# Assignments must likewise pass the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    OKAY { $my_scalar    = $good_value }  "   my scalar = $good_value_str";
    OKAY { $our_scalar   = $good_value }  "  our scalar = $good_value_str";
    OKAY { $state_scalar = $good_value }  "state scalar = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_ASSIGN { $my_scalar    = $bad_value }  "   my scalar = $bad_value_str";
    FAIL_ON_ASSIGN { $our_scalar   = $bad_value }  "  our scalar = $bad_value_str";
    FAIL_ON_ASSIGN { $state_scalar = $bad_value }  "state scalar = $bad_value_str";
}


# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(REF)                     { my $x :of(REF) = shift; return $x }
      sub   new_sub :returns(REF)  ($param :of(REF))  { return $param }
my    sub    my_sub :returns(REF)  ($param :of(REF))  { return $param }
state sub state_sub :returns(REF)  ($param :of(REF))  { return $param }

      sub   old_ret_sub : returns(REF)            { return shift  }
      sub   new_ret_sub : returns(REF)  ($param)  { return $param }
my    sub    my_ret_sub : returns(REF)  ($param)  { return $param }
state sub state_ret_sub : returns(REF)  ($param)  { return $param }

# With values that should pass the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    # Scalar context return okay...
    OKAY { scalar   old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { scalar   new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { scalar    my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { scalar state_sub( $good_value ) }   "state_sub( $good_value_str )";

    # List context return okay if list length = 1...
    OKAY { () =     old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( $good_value ) }   "state_sub( $good_value_str )";

    # Void context return fails...
    FAIL_ON_RETURN {;   old_ret_sub( $good_value ) }   "  old_sub( $good_value_str )";
    FAIL_ON_RETURN {;   new_ret_sub( $good_value ) }   "  new_sub( $good_value_str )";
    FAIL_ON_RETURN {;    my_ret_sub( $good_value ) }   "   my_sub( $good_value_str )";
    FAIL_ON_RETURN {; state_ret_sub( $good_value ) }   "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar   old_sub( $bad_value ) }       "  old_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar   new_sub( $bad_value ) }       "  new_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar    my_sub( $bad_value ) }       "   my_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar state_sub( $bad_value ) }       "state_sub( $bad_value_str )";

    # Can't return invalid values in any context...
    FAIL_ON_RETURN { scalar   old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
    FAIL_ON_RETURN { () =     old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN { () =     new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN { () =      my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN { () =   state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
    FAIL_ON_RETURN {;         old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN {;         new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN {;          my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN {;       state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
}

done_testing();


