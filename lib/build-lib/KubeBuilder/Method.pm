package KubeBuilder::Method;
  use Moose;
  use KubeBuilder::Property;

  has operation => (is => 'ro', required => 1, isa => 'Swagger::Schema::Operation');

  has name => (is => 'ro', isa => 'Str', required => 1);

  has root_schema => (
    is => 'ro',
    isa => 'KubeBuilder',
    weak_ref => 1,
    required => 1,
  );

  has url => (is => 'ro', isa => 'Str', required => 1);
  has method => (is => 'ro', isa => 'Str', required => 1);

  has call_classname => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    my $mname = $self->operation->operationId;
    substr($mname, 0, 1) = uc(substr($mname, 0, 1));
    return $mname;
  });

  has call_namespace => (is => 'ro', isa => 'Str', default => 'Kubernetes::REST::Call::');
  has fullyqualified_methodname => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    $self->call_namespace . $self->call_classname;
  });

  sub swagger_to_perltype {
    my ($self, $param) = @_;

    return 'Defined' if ($param->{ schema });

    my $type = $param->{ type };
    if      ($type eq 'string') {
      return 'Str';
    } elsif ($type eq 'integer') {
      return 'Int';
    } elsif ($type eq 'boolean') {
      return 'Bool';
    } elsif ($type eq 'number') {
      return 'Num';
    } else {
      die "Unknown type $type";
    }
  }

  has common_parameters => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

  has parameters => (is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
    my $self = shift;
    my @params;
    return [] if (not defined $self->operation->parameters);

use Data::Dumper;
print Dumper($self->fullyqualified_methodname, $self->common_parameters);

    foreach my $param (@{ $self->operation->parameters }, @{ $self->common_parameters }) {
      push @params, {
        name => $param->{ name },
        required => $param->{ required },
        perl_type => $self->swagger_to_perltype($param),
        in => $param->{ in },
      };
    }

    return \@params;
  });

  has type_list => (is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
    my $self = shift;
    my %types = ( map { ($_->{ perl_type } => 1) } @{ $self->parameters } );
    return [ sort keys %types ];
  });

  sub filter_parameters {
    my $type = shift;
    return sub {
      my $self = shift;
      return [
        grep { $_->{ in } eq $type } @{ $self->parameters }
      ];
    }
  }

  has query_params => (is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => filter_parameters('query'));
  has url_params => (is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => filter_parameters('path'));
  has body_params => (is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => filter_parameters('body'));


1;