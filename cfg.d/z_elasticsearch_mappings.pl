###############################################################################
#
#  Elasticsearch mapping creation methods
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


#
# A list of field names that should not be mapped or indexed.
# Many of them are from a standard EPrints configuration and have
# never been used in ZORA. Some other are just not necessary.
#
$c->{es}->{field_exclusions} = {
	"accompaniment" => 0,
	"citation" => 0,
	"coins" => 0,
	"completion_time" => 0,
	"composition_type" => 0,
	"conductors_id" => 0,
	"contributor_lookup_lookup" => 0,
	"contributor_lookup_orcid" => 0,
	"contributor_stat_key" => 0,
	"copyright_holders" => 0,
	"data_type" => 0,
	"date_type" => 0,
	"department" => 0,
	"dir" => 0,
	"edit_lock_since" => 0,
	"edit_lock_until" => 0,
	"exhibitors_id" => 0,
	"fileinfo" => 0,
	"funders" => 0,
	"gscholar_cluster" => 0,
	"gscholar_impact" => 0,
	"harvester_eth" => 0,
	"harvester_nb" => 0,
	"harvester_swissbib" => 0,
	"has_original_cover" => 0,
	"ispublished" => 0,
	"item_issues2_comment" => 0,
	"item_issues2_count" => 0,
	"item_issues2_description" => 0,
	"item_issues2_id" => 0,
	"item_issues2_status" => 0,
	"item_issues2_type" => 0,
	"item_issues_comment" => 0,
	"item_issues_count" => 0,
	"item_issues_description" => 0,
	"item_issues_id" => 0,
	"item_issues_status" => 0,
	"item_issues_type" => 0,
	"language" => 0,
	"latitude" => 0,
	"learning_level" => 0,
	"longitude" => 0,
	"lyricists_id" => 0,
	"metadata_visibility" => 0,
	"monograph_type" => 0,
	"ms_thesis_agreement" => 0,
	"num_pieces" => 0,
	"output_media" => 0,
	"patent_applicant" => 0,
	"pedagogic_type" => 0,
	"phd_thesis_agreement" => 0,
	"pres_type" => 0,
	"producers_id" => 0,
	"projects" => 0,
	"referencetext" => 0,
	"related_item_relation" => 0,
	"skill_areas" => 0,
	"submitter_contact" => 0,
	"submitter_contact_status" => 0,
	"suggestions" => 0,
	"swissbib" => 0,
	"sword_slug" => 0,
	"task_purpose" => 0,
	"thesis_type" => 0,
	"title_webpage" => 0,
};


###############################################################################
# 
# Mapping creation methods are grouped in 5 classes:
# 1. Named fields requiring special treatment (e.g. compound fields) 
# 2. By field type
# 3. Citation
# 4. Fulltext index
# 5. Document data
# 6. Aggregations
# 7. Field aliases
#
###############################################################################

#
# 2. By field type
#

# boolean field type
$c->{es_mapping_type_boolean} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_boolean = {
		$fieldname => {
			type => "boolean",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_boolean );
	
	return 1;
};

# text field type
$c->{es_mapping_type_text} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_text = {
		$fieldname => {
			type => "text",
			index_options => "offsets",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_text );
	
	return 1;
};

# longtext field type
$c->{es_mapping_type_longtext} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_longtext = {
		$fieldname => {
			type => "text",
			index_options => "offsets",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_longtext );
	
	return 1;
};

# id field type
$c->{es_mapping_type_id} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_id = {
		$fieldname => {
			type => "keyword",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_id );
	
	return 1;
};

# date field type
$c->{es_mapping_type_date} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_date = {
		$fieldname => {
			type => "date",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_date );
	
	return 1;
};

# time (=date/timestamp) field type
$c->{es_mapping_type_time} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_time = {
		$fieldname => {
			type => "date",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_time );
	
	return 1;
};

# timestamp field type
$c->{es_mapping_type_timestamp} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_timestamp = {
		$fieldname => {
			type => "date",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_timestamp );
	
	return 1;
};

# integer field type
$c->{es_mapping_type_int} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_int = {
		$fieldname => {
			type => "integer",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_int );
	
	return 1;
};

# float field type
$c->{es_mapping_type_float} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_float = {
		$fieldname => {
			type => "float",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_float );
	
	return 1;
};

# year field type
$c->{es_mapping_type_year} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_year = {
		$fieldname => {
			type => "integer",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_year );
	
	return 1;
};

# pagerange field type
$c->{es_mapping_type_pagerange} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_pagerange = {
		$fieldname => {
			type => "text",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_pagerange );
	
	return 1;
};

# set field type, multilanguage
$c->{es_mapping_type_set} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_set = {
		$fieldname => {
			type => "nested",
			properties => {
				key => {
					type => "keyword",
				},
				phrases => {
					type => "nested",
					properties => {
						lang => {
							type => "keyword",
						},
						phrase => {
							type => "keyword",
						},
					},
				},
			},
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_set );
	
	return 1;
};

# namedset field type, multilanguage
$c->{es_mapping_type_namedset} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_namedset = {
		$fieldname => {
			type => "nested",
			properties => {
				key => {
					type => "keyword",
				},
				phrases => {
					type => "nested",
					properties => {
						lang => {
							type => "keyword",
						},
						phrase => {
							type => "keyword",
						},
					},
				},
			},
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_namedset );
	
	return 1;
};

# url field type
$c->{es_mapping_type_url} = sub
{
	my ($fieldname, $mapping_fields) = @_;
	
	my $mapping_url = {
		$fieldname => {
			type => "text",
			analyzer => "simple",
		},
	};
	
	%$mapping_fields = ( %$mapping_fields, %$mapping_url );
	
	return 1;
};


#
# 5. Document data
#
$c->{es_mapping_eprint_documentdata} = sub
{
	my ($mapping_documentdata) = @_;
	
	my $mapping_docs = {
		docid => {
			type => "keyword",
		},
		content => {
			type => "keyword",
		},
		date_embargo => {
			type => "date",
		},
		format => {
			type => "keyword",
		},
		formatdesc => {
			type => "keyword",
		},
		license => {
			type => "keyword",
		},
		security => {
			type => "keyword",
		},
	};
	
	%$mapping_documentdata = %$mapping_docs;
	
	return 1;
};


#
# 6. Aggregations
#

# Aggregation by key
$c->{es_mapping_agg_eprint_key} = sub
{
	my ($repo, $aggname, $mapping_aggregations) = @_;
	
	my $aggfield = "agg_" . $aggname . "_key";
	
	my $mapping_aggregation = {
		$aggfield => {
			type => "keyword",
		},
	};
	
	%$mapping_aggregations = ( %$mapping_aggregations, %$mapping_aggregation );
	
	return 1;
};


# Aggregation by language
$c->{es_mapping_agg_eprint_language} = sub
{
	my ($repo, $aggname, $mapping_aggregations) = @_;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		my $aggfield = "agg_" . $aggname . "_" . $langid;
		
		my $mapping_aggregation = {
			$aggfield => {
				type => "keyword",
			},
		};
	
		%$mapping_aggregations = ( %$mapping_aggregations, %$mapping_aggregation );
	}

	return 1;
};

#
# 7. Field aliases
#

# generic
$c->{es_mapping_aliases_eprint} = sub
{
	my ($repo, $alias, $mapping_aliases) = @_;
	
	my $mapping_alias = {
		$alias->{alias} => {
			type => "alias",
			path => $alias->{path},
		},
	};
	
	%$mapping_aliases = ( %$mapping_aliases, %$mapping_alias );
	
	return 1;
};

