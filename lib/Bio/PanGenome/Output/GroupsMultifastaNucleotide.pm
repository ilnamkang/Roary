package Bio::PanGenome::Output::GroupsMultifastaNucleotide;

# ABSTRACT:  Take in a GFF files and a groups file and output one multifasta file per group with nucleotide sequences.

=head1 SYNOPSIS

Take in a GFF files and a groups file and output one multifasta file per group with nucleotide sequences.
   use Bio::PanGenome::Output::GroupsMultifastas;
   
   my $obj = Bio::PanGenome::Output::GroupsMultifastasNucleotide->new(
       group_names      => ['aaa','bbb'],
       analyse_groups  => $analyse_groups
     );
   $obj->populate_files();

=cut

use Moose;
use Bio::SeqIO;
use File::Path qw(make_path);
use Bio::PanGenome::Exceptions;
use Bio::PanGenome::AnalyseGroups;

has 'gff_file'         => ( is => 'ro', isa => 'Str',                           required => 1 );
# Not implemented
has 'group_names'      => ( is => 'ro', isa => 'ArrayRef',                      required => 0 );
has 'analyse_groups'   => ( is => 'ro', isa => 'Bio::PanGenome::AnalyseGroups', required => 1 );
has 'output_directory' => ( is => 'ro', isa => 'Str',                           required => 1 );

has 'fasta_file'   => ( is => 'ro', isa => 'Str',        lazy => 1, builder => '_build_fasta_file' );
has '_input_seqio' => ( is => 'ro', isa => 'Bio::SeqIO', lazy => 1, builder => '_build__input_seqio' );

sub _build__input_seqio {
    my ($self) = @_;
    return Bio::SeqIO->new( -file => $self->fasta_file, -format => 'Fasta' );
}

sub populate_files {
    my ($self) = @_;

    while ( my $input_seq = $self->_input_seqio->next_seq() ) 
    {
        if ( $self->analyse_groups->_genes_to_groups->{$input_seq->display_id} ) 
        {
          my $current_group =  $self->analyse_groups->_genes_to_groups->{$input_seq->display_id};

          my $output_seq = $self->_group_seq_io_obj($current_group,@{$self->analyse_groups->_groups_to_gene{$current_group}});
          $output_seq->write_seq($input_seq);
        }
    }

    unlink($self->fasta_file);
    1;
}

sub _group_file_name
{ 
  my ($self,$group_name,$num_group_genes) = @_;
  $group_name =~ s!\W!_!gi;
  my $filename = join('-', ($num_group_genes,$group_name)).'.fa';
  my $group_file_name = join('/',($self->output_directory, $filename ));
  return $group_file_name;
}

sub _group_seq_io_obj
{
  my ($self,$group_name,$num_group_genes) = @_;
  my $filename = $self->_group_file_name($group_name,$num_group_genes);
  return Bio::SeqIO->new( -file => ">>".$filename, -format => 'Fasta' );
}


sub _extracted_nucleotide_fasta_file_from_bed_filename {
    my ($self) = @_;
    return join( '.', ( $self->output_filename, 'intermediate.extracted.fa' ) );
}

sub _create_bed_file_from_gff {
    my ($self) = @_;
    my $cmd =
        'sed -n \'/##gff-version 3/,/##FASTA/p\' '
      . $self->gff_file
      . ' | grep -v \'^#\' | awk \'{print $1"\t"($4-1)"\t"($5)"\t"$9"\t1\t"$7}\' | sed \'s/ID=//\' | sed \'s/;[^\t]*\t/\t/g\' > '
      . $self->_bed_output_filename;
    system($cmd);
}

sub _create_nucleotide_fasta_file_from_gff {
    my ($self) = @_;
    my $cmd =
        'sed -n \'/##FASTA/,//p\' '
      . $self->gff_file
      . ' | grep -v \'##FASTA\' > '
      . $self->_nucleotide_fasta_file_from_gff_filename;
    system($cmd);
}

sub _nucleotide_fasta_file_from_gff_filename {
    my ($self) = @_;
    return join( '.', ( $self->output_filename, 'intermediate.fa' ) );
}

sub _extract_nucleotide_regions {
    my ($self) = @_;

    $self->_create_nucleotide_fasta_file_from_gff;
    $self->_create_bed_file_from_gff;

    my $cmd =
        'bedtools getfasta -fi '
      . $self->_nucleotide_fasta_file_from_gff_filename
      . ' -bed '
      . $self->_bed_output_filename . ' -fo '
      . $self->_extracted_nucleotide_fasta_file_from_bed_filename
      . ' -name > /dev/null 2>&1';
    system($cmd);
    unlink( $self->_nucleotide_fasta_file_from_gff_filename );
    unlink( $self->_bed_output_filename );
    unlink( $self->_nucleotide_fasta_file_from_gff_filename . '.fai' );
}

sub _build_fasta_file {
    my ($self) = @_;
    $self->_extract_nucleotide_regions;
    return $self->output_filename;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

