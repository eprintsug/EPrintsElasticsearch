######################################################################
#
#  ElasticSearch Index Plugin - create ElasticSearch index mapping
#  and provide methods for modifying the index
#
#  Part of https://idbugs.uzh.ch/browse/ZORA-724
#  
######################################################################
#
#  Copyright 2020- University of Zurich. All Rights Reserved.
#
#  Martin Brändle
#  Zentrale Informatik
#  Universität Zürich
#  Stampfenbachstr. 73
#  CH-8006 Zürich
#
#  The plug-ins are free software; you can redistribute them and/or modify
#  them under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The plug-ins are distributed in the hope that they will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
######################################################################


=head1 NAME

EPrints::Plugin::ES::ESIndex

=cut

=head1 METHODS

=over 4

=cut

=item $es_plugin = EPrints::Plugin::ES::ESIndex->new( %params )

=back

=cut

package EPrints::Plugin::ES::ESIndex;

use strict;
use warnings;
use utf8;

use base 'EPrints::Plugin';

use lib "/usr/local/eprints/perl_cpan/lib/perl5";

use JSON;
use Search::Elasticsearch;
use Data::Dumper;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "ES::ESIndex";
	$self->{visible} = "all";
	$self->{disable} = 0;

	return $self;
}

=pod

=item $es_object = $es_plugin->create_es_object( $role )

Main method to set up a ES object. Must be called before every ES action.

Input parameters:

$role: ES role ("account") used to connect to the ES server.

Parameters to set up the $es_object are taken from a central configuration
of the repository: archives/{repositoryname}/cfg/cfg.d/z_elasticsearch.pl

$c->{es}->{scheme}          transport scheme
$c->{es}->{host}            array of nodes
$c->{es}->{port}            ES port
$c->{es}->{path}            path of the index
$c->{es}->{index}           index name
$c->{es}->{info}->{admin}   admin role name for administration of index
$c->{es}->{info}->{user}    user role name for querying index
$c->{es}->{cxn}             client method for connecting to ES server
$c->{es}->{client}          Search::ElasticSearch client

Returns: an ES object

=cut

sub create_es_object
{
	my ($self, $role ) = @_;

	my $repo = $self->{repository};
	my $session = $self->{session};
	
	# Create the ES object and contact the ES server
	my $es_scheme    = $repo->get_conf( "es", "scheme" );
	my $es_host      = $repo->get_conf( "es", "host" );
	my $es_port      = $repo->get_conf( "es", "port" );
	my $es_path      = $repo->get_conf( "es", "path" );
	my $es_userinfo  = $repo->get_conf( "es", "info", $role );
	my $es_cxn       = $repo->get_conf( "es", "cxn" );
	my $es_client    = $repo->get_conf( "es", "client" );
	
	my @nodes;
	
	foreach my $node (@$es_host)
	{
		push @nodes, {
			scheme   => $es_scheme,
			host     => $node,
			port     => $es_port,
			userinfo => $es_userinfo,
			path     => $es_path, 
		};
	} 
	
	my $es = eval {
	    Search::Elasticsearch->new(
	    	client => $es_client,
	        nodes => @nodes,
	        cxn => $es_cxn,
	
	        # trace_to => 'Stderr',
	    );
	};

	# check if connection established / credentials must be used
	if ($@) {
    	print STDERR "Connection to ES Host $es_host could not be established\n";
    	exit 1;
	}

	return $es;
}


=pod

=item $ret = $es_plugin->create_index()

Creates an empty index on the ES server using the ES object.

Index name and static settings are taken from
archives/{repositoryname}/cfg/cfg.d/z_elasticsearch.pl :

$c->{es}->{index}
$c->{es}->{static_settings}

Returns: a result object containing the error status.

=cut

sub create_index
{
	my ($self) = @_;
	
	my $repo = $self->{repository};
	
	my $e = $self->create_es_object( "admin" );
	my $index_name = $repo->get_conf( "es", "index" );
	my $settings = $repo->get_conf( "es", "static_settings" );
	
	my $response = $e->indices->create( 
		index => $index_name,
		body => {
			settings => {
				index => $settings,
			},
		},
	);
	
	my $result = $self->error_handler( $response );
	
	return $result;
}

=pod

=item $ret = $es_plugin->delete_index()

Deletes an index on the ES server using the ES object completely.

Index name is taken from archives/{repositoryname}/cfg/cfg.d/z_elasticsearch.pl :

$c->{es}->{index}

Returns: a result object containing the error status.

=cut

sub delete_index
{
	my ($self) = @_;
	
	my $repo = $self->{repository};
	
	my $e = $self->create_es_object( "admin" );
	my $index_name = $repo->get_conf( "es", "index" );
	
	my $response = $e->indices->delete( index => $index_name );
	
	my $result = $self->error_handler( $response );
	
	return $result;
}

=pod

=item $ret = $es_plugin->create_mapping()

Creates the mapping on an index. 

General structure of the mapping:

id
aggregations
metadata
citation
documents
fulltext

creating_mapping() is an abstract method. It calls sub methods depending on 

aggregation name
field name  (mostly used for commpound fields)
field type
fulltext

These methods are defined in archives/{repositoryname}/cfg/cfg.d/z_elasticsearch_mappings.pl
See documentation there.

Also there a list of fields that shall not be indexed can be defined in the
configuration:

$c->{es}->{field_exclusions}


Returns: a result object containing the error status.

=cut


sub create_mapping
{
	my ($self) = @_;
	
	my $response;
	my $result;
	my $repo = $self->{repository};
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	my $aggregations = $repo->get_conf( "es", "aggs" );
	my $field_exclusions = $repo->get_conf( "es", "field_exclusions" );
	my $citation_styles = $repo->get_conf( "es", "citation_styles" );
	
	my $ret = $self->update_settings();
	return $ret if ( $ret->{error} != 0 );
	
	my $mapping = {};
	my $mapping_fields = {};
	my $mapping_citation = {};
	my $mapping_fulltext = {};
	my $mapping_documentdata = {};
	my $mapping_aggregations = {};
	my $mapping_aliases = {};
	
	# Read configuration for datasets to build index structure upon
	my $datasetids = $repo->get_conf( "es", "datasets");
	
	foreach my $datasetid (@$datasetids)
	{
		my $dataset = $repo->dataset( $datasetid );
		
		my @dataset_fields = $dataset->fields;
		
		foreach my $field ( @dataset_fields )
		{
			
			my $fieldname = $field->name;
			my $fieldtype = $field->type;
			my $mapping_fn = "es_mapping_" . $datasetid . "_" . $fieldname;
			my $mapping_fn_type = "es_mapping_type_" . $fieldtype;
			
			# don't map excluded fields
			next if ( defined $field_exclusions->{$fieldname} && $field_exclusions->{$fieldname} == 0);
			
			# don't map volatile fields
			next if ( $field->property( "volatile" ) && $fieldname ne "lastmod" );
			
			# don't map subfields of a compound field a second time if there's a mapping method for the compound field
			my $parentname = $field->property( "parent_name" );
			next if (defined $parentname && $repo->can_call( "es_mapping_" . $datasetid . "_" . $parentname ));
			
			
			if ($repo->can_call( $mapping_fn ))
			{
				$ret = $repo->call( $mapping_fn, $fieldname, $mapping_fields );
			}
			elsif ($repo->can_call( $mapping_fn_type ))
			{
				$ret = $repo->call( $mapping_fn_type, $fieldname, $mapping_fields );
			}
			else
			{
			}
		}
		
		# Additional mappings
		# Citations
		foreach my $style (@$citation_styles)
		{
			my $mapping_fn_citation = "es_mapping_" . $datasetid . "_citation_" . $style;
			if ($repo->can_call( $mapping_fn_citation ))
			{
				$ret = $repo->call( $mapping_fn_citation, $mapping_citation);
			}
		}
		
		# Fulltext
		my $mapping_fn_fulltext = "es_mapping_" . $datasetid . "_fulltext";
		if ($repo->can_call( $mapping_fn_fulltext ))
		{
			$ret = $repo->call( $mapping_fn_fulltext, $mapping_fulltext );
		}
		
		# Document data
		my $mapping_fn_documentdata = "es_mapping_" . $datasetid . "_documentdata";
		if ($repo->can_call( $mapping_fn_documentdata ))
		{
			$ret = $repo->call( $mapping_fn_documentdata, $mapping_documentdata );
		}
		
		# Aggregations
		# here we call by type and pass the name
		foreach my $agg (@$aggregations)
		{
			my $mapping_fn_aggregation = "es_mapping_agg_" . $datasetid . "_" . $agg->{type};
			if ($repo->can_call( $mapping_fn_aggregation ) )
			{
				$ret = $repo->call( $mapping_fn_aggregation, $repo, $agg->{name}, $mapping_aggregations );
			}
		}
		
		# Field aliases
		my $aliases = $repo->get_conf( "es", "aliases", $datasetid );
		foreach my $alias (@$aliases)
		{
			my $mapping_fn_aliases = "es_mapping_aliases_" . $datasetid;
			
			if ($alias->{expand} == 1)
			{
				$mapping_fn_aliases = "es_mapping_aliases_" . $datasetid . "_" . $alias->{alias};
			}
			
			if ($repo->can_call( $mapping_fn_aliases ) )
			{
				$ret = $repo->call( $mapping_fn_aliases, $repo, $alias, $mapping_aliases);
			}
		}
		
		$mapping = {
			properties => {
				id => { 
					type => "integer",
				},
				%$mapping_aggregations,
				metadata => {
					properties => {
						$datasetid => {
							properties => {
								%$mapping_fields,
							},
						},
					},
				},
				citation => {
					properties => {
						$datasetid => {
							properties => {
								%$mapping_citation,
							},
						},
					},
				},
				documents => {
					properties => {
						$datasetid => {
							properties => {
								%$mapping_documentdata,
							},
						},
					},
				},
				fulltext => {
					properties => {
						$datasetid => {
							properties => {
								%$mapping_fulltext,
							},
						},
					},
				},
				%$mapping_aliases,
			},
		};
		
		$response = $e->indices->put_mapping(
			index => $indexname,
			body => $mapping,
		);
		
		$result = $self->error_handler( $response );
	}
	
	return $result;
}

=pod

=item $ret = $es_plugin->update_settings()

Update the dynamic settings on an index.

Settings are taken from archives/{repositoryname}/cfg/cfg.d/z_elasticsearch.pl :

$c->{es}->{dynamic_settings}

Returns: a result object containing the error status.

=cut

sub update_settings
{
	my ($self) = @_;
	
	my $repo = $self->{repository};
	
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	my $settings = $repo->get_conf( "es", "dynamic_settings" );
	
	my $response = $e->indices->put_settings(
		index => $indexname,
		body => $settings,
	);
	my $result = $self->error_handler( $response );
	
	return $result;
}

=pod

=item $ret = $es_plugin->index_all( $dataobj, %opts )

Index all fields of a data object $dataobj.

=cut

sub index_all
{
	my ($self, $dataobj, %opts) = @_;
	
	my $dataset = $dataobj->get_dataset;
	my @fields = $dataset->get_fields;
	my $fields_ref = \@fields;
	
	$self->index_fields( $dataobj, $fields_ref );
	
	return;
}

=pod

=item $ret = $es_plugin->index_fields( $dataobj, $fields, %opts )

Index or reindex the fields in the list $fields of a data object $dataobj.

=cut

sub index_fields
{
	my ($self, $dataobj, $fields, %opts) = @_;
	
	my $dataset = $dataobj->dataset;
	my $dataset_id = $dataset->base_id;
	my $item_id = $dataobj->id;
	my $repo = $self->{repository};
	
	# If change was triggered by document, we index fully based on parent eprint
	if ($dataset_id eq "document")
	{
		my $eprint = $dataobj->get_eprint();
		$self->index_all( $eprint );
		return;
	}
	
	# Check if the object's dataset belongs to the indexable datasets
	return unless $self->is_indexable( $dataset_id );
	
	# Create the ES object
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	
	# Check if we can carry out a partial update
	my $partial_update = 0;
	my @fields_all = $dataset->get_fields;
	if (scalar @$fields < scalar @fields_all)
	{
		my $response_exists = $e->exists(
			index => $indexname,
			id => $item_id
		);
		$partial_update = 1 if (defined $response_exists && $response_exists == 1);
	}
	
	my $index_data = {};
	my $index_fields = {};
	my $index_aggregations = {};
	my $index_citation = {};
	my $index_documentdata = {};
	my $index_fulltext = {};
	
	my $aggregations = $repo->get_conf( "es", "aggs" );
	my $field_exclusions = $repo->get_conf( "es", "field_exclusions" );
	my $citation_styles =  $repo->get_conf( "es", "citation_styles" );
	
	foreach my $field (@$fields)
	{
		my $fieldname = $field->name;
		my $fieldtype = $field->type;
		my $index_fn = "es_index_" . $dataset_id . "_" . $fieldname;
		my $index_fn_type = "es_index_type_" . $fieldtype;
		
		# don't index excluded fields
		next if ( defined $field_exclusions->{$fieldname} && $field_exclusions->{$fieldname} == 0);
		
		# don't index volatile fields
		next if ( $field->property( "volatile" ) && $fieldname ne "lastmod" );
			
		# don't index subfields of a compound field a second time if there's a indexing function for the compound field
		my $parentname = $field->property( "parent_name" );
		next if (defined $parentname && $repo->can_call( "es_index_" . $dataset_id . "_" . $parentname ));
		
		if ($repo->can_call( $index_fn ))
		{
			my $ret = $repo->call( $index_fn, $repo, $dataobj, $field, $index_fields );
		}
		elsif ($repo->can_call( $index_fn_type ))
		{
			my $ret = $repo->call( $index_fn_type, $repo, $dataobj, $field, $index_fields );
		}
		else
		{}
	}
	
	# Aggregations
	# here we call by name only
	foreach my $agg (@$aggregations)
	{
		my $index_fn_aggregation = "es_index_agg_" . $dataset_id . "_" . $agg->{name};
		
		if ($repo->can_call( $index_fn_aggregation ) )
		{
			my $ret = $repo->call( $index_fn_aggregation, $repo, $dataobj, $index_aggregations );
		}
	}
	
	# Citation
	# the citation is always calculated regardless of the fields that were changed; 
	# this adds some cost, but makes life easier
	foreach my $style (@$citation_styles)
	{
		my $index_fn_citation = "es_index_" . $dataset_id . "_citation_" . $style;

		if ($repo->can_call( $index_fn_citation ))
		{
			my $ret = $repo->call( $index_fn_citation, $repo, $dataobj, $index_citation );
		}
	}
	
	# Documents
	my $index_fn_documentdata = "es_index_" . $dataset_id . "_documentdata";
	if ($repo->can_call( $index_fn_documentdata ))
	{
		my $ret = $repo->call( $index_fn_documentdata, $repo, $dataobj, $index_documentdata );
	}
	
	my $response;
	if ($partial_update)
	{
		$index_data = {
			id => $item_id,
			%$index_aggregations,
			metadata => {
				$dataset_id => { %$index_fields },
			},
			citation => {
				$dataset_id => { %$index_citation },
			},
			documents => { %$index_documentdata },
		};
		
		$response = $e->update(
			index => $indexname,
			id => $item_id,
			body => { doc => { %$index_data } },
		);
	}
	else
	{
		# In case of full indexing get fulltext as well
		my $index_fn_fulltext = "es_index_" . $dataset_id . "_fulltext";
		if ($repo->can_call( $index_fn_fulltext))
		{
			my $ret = $repo->call( $index_fn_fulltext, $repo, $dataobj, $index_fulltext );
		}
		
		$index_data = {
			id => $item_id,
			%$index_aggregations,
			metadata => {
				$dataset_id => { %$index_fields  },
			},
			citation => {
				$dataset_id => { %$index_citation },
			},
			documents => { %$index_documentdata },
			fulltext => { %$index_fulltext },
		};
		
		$response = $e->index(
			index => $indexname,
			id => $item_id,
			body => { %$index_data },
		);
	}
	
	my $result = $self->error_handler( $response );
	
	# Update the log if action was successful
	if ($result->{error} == 0)
	{
		$self->write_log( $repo->id, $dataset_id, $item_id, $partial_update);
	}
	
	return;
}

=pod

=item $ret = $es_plugin->remove_index_item( $dataset, $item_id )

Removes an item from the index with id $item_id and dataset $dataset.

=cut

sub remove_index_item
{
	my ($self, $dataset, $item_id) = @_;
	
	my $dataset_id = $dataset->base_id;
	my $repo = $self->{repository};
	
	return unless $self->is_indexable( $dataset_id );
	
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	
	# check first if the item exists (trigger may be concurring against direct indexing)
	my $response_exists = $e->exists(
		index => $indexname,
		id => $item_id
	);
	
	if (defined $response_exists && $response_exists == 1)
	{
		my $response = $e->delete(
			index => $indexname,
			id => $item_id,
		);
	
		my $result = $self->error_handler( $response );
	
		if ($result->{error} == 0)
		{
			$self->write_log( $repo->id, $dataset_id, $item_id, -1);
		}
	}
	
	return;
}

=pod

=item $ret = $es_plugin->repair_index_item( $item )

Repairs an item from the index given an EPrints dataobj $item .

Returns a repair status (0 = no action, 1 = item added, 2 = item updated)

=cut

sub repair_index_item
{
	my ($self, $dataobj) = @_;
	
	my $dataset = $dataobj->dataset;
	my $dataset_id = $dataset->base_id;
	my $item_id = $dataobj->id;
	my $repo = $self->{repository};
	
	return unless $self->is_indexable( $dataset_id );
	
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	
	my $response_exists = $e->exists(
		index => $indexname,
		id => $item_id
	);
	
	if (!defined $response_exists)
	{
		$self->index_all( $dataobj );
		return 1;
	}

	if (defined $response_exists && $response_exists != 1)
	{
		$self->index_all( $dataobj );
		return 1;
	}
	
	if (defined $response_exists && $response_exists == 1)
	{
		my $index_item = $e->get(
			index => $indexname,
			id => $item_id,
			"_source" => "metadata.eprint.lastmod"
		);
		
		my $lastmod_es = $index_item->{_source}->{metadata}->{eprint}->{lastmod};
		if (defined $lastmod_es)
		{
			$lastmod_es =~ s/T/ /g;
			my $lastmod_ep = $dataobj->get_value( "lastmod" );
			
			my @t_es = EPrints::Time::split_value( $lastmod_es );
			my @t_ep = EPrints::Time::split_value( $lastmod_ep );
			my $time_es = EPrints::Time::datetime_utc( @t_es );
			my $time_ep = EPrints::Time::datetime_utc( @t_ep );
			
			if ($time_ep > $time_es)
			{
				$self->index_all( $dataobj );
				return 2;
			}
			elsif ($time_ep < $time_es)
			{
				print STDERR "ERROR: eprint $item_id is older ($lastmod_ep) than the ES item ($lastmod_es)! Please investigate\n";
				return 0;
			}
			else
			{
				return 0;
			}
		}
		else
		{
			print STDERR "ERROR: lastmod field is missing in ES index. Please check mapping.\n";
			return 0;
		}
	}
	
	return 0;
}

=pod

=item $count = $es_plugin->get_record_count()

Returns: the count of records in the ES index

=cut

sub get_record_count
{
	my ($self) = @_;
	
	my $repo = $self->{repository};
	
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	
	my $response = $e->count(
		index => $indexname,
	);
	
	my $count = $response->{count};
	
	return $count;
}

=pod

=item $ret = $es_plugin->compare_index_item( $item )

Compares an EPrints dataobj $item with its equivalent in the ES index. 
Existence and modification date are compared.
Works similarly to $es_plugin->repair_index_item( $item ), but without 
reindexing.

Returns 0

=cut

sub compare_index_item
{
	my ($self, $dataobj) = @_;
	
	my $dataset = $dataobj->dataset;
	my $dataset_id = $dataset->base_id;
	my $item_id = $dataobj->id;
	my $repo = $self->{repository};
	
	return unless $self->is_indexable( $dataset_id );
	
	my $e = $self->create_es_object( "admin" );
	my $indexname = $repo->get_conf( "es", "index" );
	
	my $response_exists = $e->exists(
		index => $indexname,
		id => $item_id
	);
	
	if (!defined $response_exists)
	{
		print STDOUT "Item $item_id (dataset $dataset_id) is missing in ES index. Consider repair/reindex\n";
	}

	if (defined $response_exists && $response_exists != 1)
	{
		print STDOUT "Item $item_id (dataset $dataset_id) is missing in ES index. Consider repair/reindex\n";
	}
	
	if (defined $response_exists && $response_exists == 1)
	{
		my $index_item = $e->get(
			index => $indexname,
			id => $item_id,
			"_source" => "metadata.eprint.lastmod"
		);
		
		my $lastmod_es = $index_item->{_source}->{metadata}->{eprint}->{lastmod};
		if (defined $lastmod_es)
		{
			$lastmod_es =~ s/T/ /g;
			my $lastmod_ep = $dataobj->get_value( "lastmod" );
			
			my @t_es = EPrints::Time::split_value( $lastmod_es );
			my @t_ep = EPrints::Time::split_value( $lastmod_ep );
			my $time_es = EPrints::Time::datetime_utc( @t_es );
			my $time_ep = EPrints::Time::datetime_utc( @t_ep );
			
			if ($time_ep > $time_es)
			{
				print STDOUT "eprint $item_id is younger ($lastmod_ep) than corresponding ES record ($lastmod_es). Consider repair/reindex\n" 
			}
			
			if ($time_ep < $time_es)
			{
				print STDERR "ERROR: eprint $item_id is older ($lastmod_ep) than corresponging ES item ($lastmod_es)! Please investigate\n";
			}
		}
		else
		{
			print STDERR "ERROR: lastmod field is missing in ES index. Please check mapping.\n";
		}
	}
	
	return 0;
}


=pod

=item $ret = $es_plugin->error_handler( $response )

Parses the ES response and sets a result object containing 
the error status. 

Returns: a result object containing the error status.

=cut

sub error_handler
{
	my ($self, $r) = @_;
	
	my $feedback = {};
	
	if (defined $r->{acknowledged} && $r->{acknowledged} eq 'true')
	{
		$feedback->{error} = 0;
	}
	elsif (defined $r->{result} && $r->{result} eq 'created')
	{
		$feedback->{error} = 0;
	}
	elsif (defined $r->{result} && $r->{result} eq 'updated')
	{
		$feedback->{error} = 0;
	}
	elsif (defined $r->{result} && $r->{result} eq 'deleted')
	{
		$feedback->{error} = 0;
	}
	else
	{ 
		print STDERR Dumper( $r );
		$feedback->{error} = 1;
	}
	
	return $feedback;
}

=pod

=item $es_plugin->write_log( $repo_id, $dataset_id, $item_id, $update )

Writes a status message to the indexer.log

=cut

sub write_log
{
	my ($self, $repo_id, $dataset_id, $item_id, $update) = @_;
	
	my $status = " indexed";
	$status = " index updated" if ($update == 1);
	$status = " index removed" if ($update == -1);
	
	my $logfile = EPrints::Index::logfile();
	open( STDERR, ">>", $logfile ) or warn "Couldn't open $logfile.";
   	my $logmessage = "ES: " . $repo_id . ': ' . $dataset_id . '.' . $item_id . $status;
	EPrints::Index::indexlog($logmessage);
	close( STDERR );
	
	return;
}

=pod

=item $es_plugin->is_indexable( $dataset_id )

Returns if a dataset with id $dataset_id is allowed to be indexed by ES.

=cut

sub is_indexable
{
	my ($self, $dataset_id) = @_;
	
	my $repo = $self->{repository};
	
	my $es_datasets = $repo->get_conf( "es", "datasets" );
	my $indexable = 0;
	foreach my $es_dataset (@$es_datasets)
	{
		$indexable = 1 if ($dataset_id eq $es_dataset);
	}
	return $indexable;
}

1;
