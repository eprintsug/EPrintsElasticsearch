###############################################################################
#
#  ElasticSearch trigger methods
#
###############################################################################
#
#  Copyright 2020 University of Zurich. All Rights Reserved.
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
###############################################################################

if( EPrints::Utils::require_if_exists( "EPrints::Plugin::ES::ESIndex" ) )
{	
	$c->add_trigger( EP_TRIGGER_INDEX_FIELDS, sub 
	{
		my( %params ) = @_;

		my $repo = $params{repository};
		my $dataobj = $params{dataobj};
		my $dataset = $dataobj->dataset;
		my $fields = $params{fields};
        
		# do not index volatile documents such as thumbnails etc.
		if ($dataset->base_id eq "document")
		{
			return if $dataobj->has_relation( undef, "isVolatileVersionOf" );
		}
        
		my $es_plugin = $repo->plugin( "ES::ESIndex" );
		return if !defined $es_plugin;
        
		$es_plugin->index_fields( $dataobj, $fields );
        
		return;
	});
	
	$c->add_trigger( EP_TRIGGER_INDEX_REMOVED, sub
	{
		my( %params ) = @_;
		
		my $dataset = $params{dataset};
		my $item_id = $params{id};
		return if ($dataset->base_id eq "document");
		
		my $repo = $dataset->{repository};
		
		my $es_plugin = $repo->plugin( "ES::ESIndex" );
		return if !defined $es_plugin;
		
		$es_plugin->remove_index_item( $dataset, $item_id );
		
		return;
	});

	$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE, sub 
	{
		my( %params ) = @_;
		
		my $dataobj = $params{dataobj};
		return unless $dataobj->{dataset}->indexable && $dataobj->{dataset}->base_id eq "eprint";
		
		my $user = $dataobj->{session}->current_user;
		my $userid;
		$userid = $user->id if defined $user;
		
		EPrints::DataObj::EventQueue->create_unique( $dataobj->{session}, {
			pluginid => "Event::Indexer",
			action => "index",
			params => [$dataobj->internal_uri, 'eprint_status'],
			userid => $userid,
		});
	});
	
	
	$c->add_dataset_trigger( "document", EP_TRIGGER_REMOVED, sub
	{
		my( %params ) = @_;
		
		my $doc = $params{dataobj};
		return unless defined $doc;
		# one can't check on relations as above because these have been removed already
		return if ($doc->get_value( "format") ne "application/pdf");
		
		my $repo = $doc->repository;
		my $eprint = $doc->get_parent();
		
		return unless defined $eprint;
		
		my $es_plugin = $repo->plugin( "ES::ESIndex" );
		return if !defined $es_plugin;
		
		$es_plugin->index_all( $eprint );
		
		return;
	});
	
	
	$c->add_dataset_trigger( "eprint", EP_TRIGGER_REMOVED, sub
	{
		my( %params ) = @_;
		
		my $eprint = $params{dataobj};
		return unless defined $eprint;
		
		my $repo = $eprint->repository;
		my $dataset = $eprint->dataset;
		my $eprintid = $eprint->id;
		
		my $es_plugin = $repo->plugin( "ES::ESIndex" );
		return if !defined $es_plugin;
		
		$es_plugin->remove_index_item( $dataset, $eprintid );
		
		return;
	});
}
