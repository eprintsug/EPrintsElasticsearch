###############################################################################
#
#  ElasticSearch index methods
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

###############################################################################
# 
# Index methods are grouped in 5 classes:
# 1. Named fields requiring special treatment (e.g. compound fields) 
# 2. By field type
# 3. Citation
# 4. Fulltext index
# 5. Document data
# 6. Aggregations
#
# For each method, there is a corresponding mapping defined in 
# z_elasticsearch_mappings.pl
#
###############################################################################

#
# 1. Named fields
#

# creators (compound field)
$c->{es_index_eprint_creators} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $role = "creator";
	my $ret = $repo->call( "es_index_eprint_contributors_role", $repo, $dataobj, $field, $index_fields, $role );
	
	return 1;
};

# editors (compound field)
$c->{es_index_eprint_editors} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $role = "editor";
	my $ret = $repo->call( "es_index_eprint_contributors_role", $repo, $dataobj, $field, $index_fields, $role );
	
	return 1;
};

# examiners (compound field)
$c->{es_index_eprint_examiners} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $role = "examiner";
	my $ret = $repo->call( "es_index_eprint_contributors_role", $repo, $dataobj, $field, $index_fields, $role );
	
	return 1;
};

# generalized index method for contributor-type (creators, editors, examiners) fields
$c->{es_index_eprint_contributors_role} = sub 
{
	my ($repo, $dataobj, $field, $index_fields, $role) = @_;
	
	my $contributors_saved;
	my $contributors_search_saved;
	
	if (defined $index_fields->{contributor})
	{
		$contributors_saved = $index_fields->{contributor};
	}
	
	if (defined $index_fields->{contributor_search})
	{
		$contributors_search_saved = $index_fields->{contributor_search};
	}
	
	my $index_contributors = $repo->call( "es_index_eprint_contributors_nested", $repo, $dataobj, $field, $role, $contributors_saved);
	my $index_contributors_search = $repo->call( "es_index_eprint_contributors_search", $repo, $dataobj, $field, $role, $contributors_search_saved);
	
	%$index_fields = ( %$index_fields, %$index_contributors, %$index_contributors_search );
	
	return 1;
};

# generalized index method for nested contributor-type (creators, editors, examiners) fields
$c->{es_index_eprint_contributors_nested} = sub 
{
	my ($repo, $dataobj, $field, $role, $contributors_saved) = @_;
	
	my $session = $dataobj->get_session();
	
	my @arr_contributors = ();
	
	foreach my $contributor (@$contributors_saved)
	{
		push @arr_contributors, $contributor;
	}
	
	my $fieldname = $field->name;
	my $contributors = $dataobj->get_value( $fieldname );
	
	foreach my $contributor (@$contributors)
	{
		my $name = $contributor->{name}->{family};
		
		if (defined $contributor->{name}->{given})
		{
			$name = $name . " " . $contributor->{name}->{given};
		}
		
		my @affiliations = ();
		
		if (defined $contributor->{affiliation_ids})
		{
			my $afids = $contributor->{affiliation_ids};
			my @affil_ids = split( /\|/, $afids );
			
			foreach my $affil_id (@affil_ids)
			{
				my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $affil_id );
				next if (!defined $affilobj);
				my $org = $affilobj->get_value( "name" );
				my $city = $affilobj->get_value( "city" );
				my $country = $affilobj->get_value( "country" );
				my $country_code = $affilobj->get_value( "country_code" );
                
				push @affiliations, {
					afid => $affil_id,
					organisation => $org,
					city => $city,
					country => $country,
					country_code => $country_code,
                };
			}
		}
		
		my $orcid = "";
		$orcid = $contributor->{orcid} if (defined $contributor->{orcid});
		
		my $email = "";
		$email = $contributor->{id} if (defined $contributor->{id});
		
		my $correspondence = "false";
		$correspondence = $contributor->{correspondence} if (defined $contributor->{correspondence});
		
		push @arr_contributors, {
			name => $name,
			affiliations => [ @affiliations ],
			orcid => $orcid,
			email => $email,
			correspondence => lc($correspondence),
			role => $role,
		};
	}
	
	my $index_contributors = { contributor => [ @arr_contributors ] };
	
	return $index_contributors; 
};

# generalized index method for contributor-type (creators, editors, examiners) search fields
# this field can't be nested, used for single-line querying
# it only stores the name, ORCID ID, the organisations, the countries 
$c->{es_index_eprint_contributors_search} = sub 
{
	my ($repo, $dataobj, $field, $role, $contributors_search_saved) = @_;
	
	my $session = $dataobj->get_session();

	my @arr_contributors = ();
	
	foreach my $contributor (@$contributors_search_saved)
	{
		push @arr_contributors, $contributor;
	}
	
	my $fieldname = $field->name;
	my $contributors = $dataobj->get_value( $fieldname );
	
	foreach my $contributor (@$contributors)
	{
		my $name = $contributor->{name}->{family};
		if (defined $contributor->{name}->{given})
		{
			$name = $name . " " . $contributor->{name}->{given};
		}
		
		my @organisations = ();
		my @countries = ();
		
		if (defined $contributor->{affiliation_ids})
		{
			my $afids = $contributor->{affiliation_ids};
			my @affil_ids = split( /\|/, $afids );
			
			foreach my $affil_id (@affil_ids)
			{
				my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $affil_id );
				next if (!defined $affilobj);
				my $org = $affilobj->get_value( "name" );
				my $country = $affilobj->get_value( "country" );
				
				push @organisations, $org if (defined $org);
				push @countries, $country if (defined $country); 
			}
		}
		
		my $orcid = "";
		$orcid = $contributor->{orcid} if (defined $contributor->{orcid});
		
		push @arr_contributors, {
			name => $name,
			orcid => $orcid,
			organisation => [ @organisations ],
			country => [ @countries ],
			role => $role,
		};
	}
	
	my $index_contributors_search = { contributor_search => [ @arr_contributors ] };
	
	return $index_contributors_search; 
};


# dewey (subject-type field)
$c->{es_index_eprint_dewey} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_dewey = $repo->call( "es_index_eprint_subjects_general", $repo, $dataobj, $field, "ddc_code" );
	
	%$index_fields = ( %$index_fields, %$index_dewey );
	
	return 1;
};

# subjects (subject-type field)
$c->{es_index_eprint_subjects} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_subjects = $repo->call( "es_index_eprint_subjects_general", $repo, $dataobj, $field, "subject_code" );
	
	%$index_fields = ( %$index_fields, %$index_subjects );
	
	return 1;
};

# scopussubjects (subject-type field)
$c->{es_index_eprint_scopussubjects} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_scopussubjects = $repo->call( "es_index_eprint_subjects_general", $repo, $dataobj, $field, "subject_code" );
	
	%$index_fields = ( %$index_fields, %$index_scopussubjects );
	
	return 1;
};

# generalized index method for subject-type fields (dewey, subjects, scopussubjects)
$c->{es_index_eprint_subjects_general} = sub 
{
	my ($repo, $dataobj, $field, $code_name) = @_;
	
	my $index_classification = {};
	my @arr_classification;
	
	my $session = $dataobj->get_session();
	
	my $fieldname = $field->name;
	
	my $classification_codes = $dataobj->get_value( $fieldname );
	
	foreach my $classification_code (@$classification_codes)
	{
		my @classes;
		
		foreach my $langid (@{$repo->get_conf( "languages" )})
		{
			my $subject = EPrints::DataObj::Subject->new( $session, $classification_code );
			
			if (defined $subject)
			{
				my $pos = 0;
				my $lang_pos = 0;
				foreach my $lang (@{$subject->{data}->{name_lang}})
				{
					$lang_pos = $pos if ($lang eq $langid);
					$pos++;
				}
				
				my $subject_names = $subject->get_value( "name" );
				
				push @classes, {
					language => $langid,
					class => $subject_names->[$lang_pos]->{name},
				};
			}
		}
		
		push @arr_classification, {
			$code_name => $classification_code,
			classes => [ @classes ],
		};
	}
	
	$index_classification = { $fieldname => [ @arr_classification ] };
	
	return $index_classification;
};

# funders (compound field)
$c->{es_index_eprint_funding_reference} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_funders = {};
	
	my $fieldname = $field->name;
	
	my $funders = $dataobj->get_value( $fieldname );
	
	if (defined $funders)
	{
		$index_funders = { funder => [ @$funders ] };
		%$index_fields = ( %$index_fields, %$index_funders );
	}
		
	return 1;
};

# apc (compound field)
$c->{es_index_eprint_apc} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_apc = {};
	
	my $fieldname = $field->name;
	my $apcs = $dataobj->get_value( $fieldname );
	
	if (defined $apcs)
	{
		$index_apc = { apc => [ @$apcs ] };
		%$index_fields = ( %$index_fields, %$index_apc );
	}
	
	return 1;
};

# title, multi language indexing
$c->{es_index_eprint_title} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_title = $repo->call( "es_index_eprint_multilang", $repo, $dataobj, $field );
	%$index_fields = ( %$index_fields, %$index_title );
	
	return 1;
};


# abstract, multi language indexing
$c->{es_index_eprint_abstract} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_abstract = $repo->call( "es_index_eprint_multilang", $repo, $dataobj, $field );
	
	if (defined $index_abstract)
	{
		%$index_fields = ( %$index_fields, %$index_abstract );
	}
	
	return 1;
};

# generalized index method for multilanguage indexing of text fields (e.g. title, abstract)
$c->{es_index_eprint_multilang} = sub 
{
	my ($repo, $dataobj, $field) = @_;
	
	my $index_languages = { 
		"eng" => 1,
		"deu" => 1,
		"fra" => 1,
		"ita" => 1,
	};

	my $index_multilang = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		my $languages = $dataobj->get_value( "language_mult" );
		
		my $set_default = 1;
		my @arr_index_ml;
		foreach my $language (@$languages)
		{
			if (defined $index_languages->{$language})
			{
				$set_default = 0;
				push @arr_index_ml, {
					$language => $value,
				};
			}
		}
		if ($set_default)
		{
			push @arr_index_ml, {
				default => $value,
			};
		}
		
		$index_multilang = { $fieldname => [ @arr_index_ml ]};
	}
		
	return $index_multilang;
};

# related_url field
$c->{es_index_eprint_related_url} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $session = $dataobj->get_session();
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	
	my $index_related_url = {};
	my $fieldname = $field->name;
	
	my $related_urls = $dataobj->get_value( $fieldname );
	
	if (defined $related_urls && scalar @$related_urls)
	{
		my $current_language = $repo->get_langid;
		
		my @urls;
		
		foreach my $related_url (@$related_urls)
		{
			my @phrases;
			my $url_type = $related_url->{type};
			$url_type = "unspecified" if (!defined $url_type);
			
			foreach my $langid (@{$repo->get_conf( "languages" )})
			{
				$session->change_lang( $langid );
				
				my $phrase;
				if ($url_type ne 'unspecified')
				{
					$phrase = $session->phrase( $datasetid . "_fieldopt_" . $fieldname . "_type_" . $url_type );
				}
				else
				{ 
					$phrase = "Unspecified";
				}
				
				push @phrases, {
					lang => $langid,
					phrase => $phrase,
				};
			}
			
			push @urls, {
				url => $related_url->{url},
				urltype => {
					key => $url_type,
					phrases => [ @phrases ],
				},
			};
		}
		
		$session->change_lang( $current_language );
		
		$index_related_url = { $fieldname => [ @urls ] };
		%$index_fields = ( %$index_fields, %$index_related_url );
	}
	
	return 1;
};

# full_text_status
$c->{es_index_eprint_full_text_status} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_full_text_status = {};
	my $index_fulltext_available = {};
	
	my $session = $dataobj->get_session();
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	
	my $fieldname = $field->name;
	
	my $value = $dataobj->get_value( $fieldname );
	if (defined $value)
	{
		my $current_language = $repo->get_langid;
			
		my @phrases;
			
		foreach my $langid (@{$repo->get_conf( "languages" )})
		{
			$session->change_lang( $langid );
			my $phrase = $session->phrase( $datasetid . "_fieldopt_" . $fieldname . "_" . $value );
				
			push @phrases, {
				lang => $langid,
				phrase => $phrase,
			};
		}
			
		$index_full_text_status = {
			$fieldname => {
					key => $value,
					phrases => [ @phrases ],
			},
		};
		
		$session->change_lang( $current_language );
		
		my $available = "0";
		if ($value eq "public" || $value eq "restricted")
		{
			$available = "1";
		}
		$index_fulltext_available = { fulltext_available => $available };
		
		%$index_fields = ( %$index_fields, %$index_full_text_status, %$index_fulltext_available );
	}
	
	return 1;
};

# OA status
$c->{es_index_eprint_oa_status} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_oa_status = {};
	my $index_oa_status_search = {};
	
	my $session = $dataobj->get_session();
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	
	my $fieldname = $field->name;
	
	my $value = $dataobj->get_value( $fieldname );
	if (defined $value)
	{
		my $current_language = $repo->get_langid;
			
		my @phrases;
			
		foreach my $langid (@{$repo->get_conf( "languages" )})
		{
			$session->change_lang( $langid );
			my $phrase = $session->phrase( $datasetid . "_fieldopt_" . $fieldname . "_" . $value );
				
			push @phrases, {
				lang => $langid,
				phrase => $phrase,
			};
		}
			
		$index_oa_status = {
			$fieldname => {
					key => $value,
					phrases => [ @phrases ],
			},
		};
		
		$session->change_lang( $current_language );
		
		$index_oa_status_search = { oa_status_search => $value };
		
		%$index_fields = ( %$index_fields, %$index_oa_status, %$index_oa_status_search );
	}
	
	return 1;
};

#
# 2. By field type
#

# boolean type fields
$c->{es_index_type_boolean} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_boolean = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$value = lc($value);
		$index_boolean = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_boolean );
	}
	
	return 1;
};

# text type fields
$c->{es_index_type_text} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_text = {};
	
	my $fieldname = $field->name;
	my $multiple = $field->property( "multiple" );
	my $value = $dataobj->get_value( $fieldname );
	
	if ($multiple && scalar @$value)
	{
		$index_text = { $fieldname => [ @$value ] };
		%$index_fields = ( %$index_fields, %$index_text );
	}
	elsif (defined $value)
	{
		$index_text = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_text );
	}
	else
	{}
	
	return 1;
};

# longtext type fields
$c->{es_index_type_longtext} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_longtext = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_longtext = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_longtext );
	}
	
	return 1;
};

# id type fields
$c->{es_index_type_id} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_id = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_id = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_id );
	}
	
	return 1;
};

# date type fields
$c->{es_index_type_date} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_date = {};
	
	my $fieldname = $field->name;
	my $multiple = $field->property( "multiple" );
	
	if ($multiple)
	{
		my @index_values;
		
		my $values = $dataobj->get_value( $fieldname );
		foreach my $value (@$values)
		{
			$value = $repo->call( "es_validate_date", $dataobj, $fieldname, $value );
			push @index_values, $value;
		}
		
		if (scalar @index_values)
		{
			$index_date = { $fieldname => [ @index_values ] };
			%$index_fields = ( %$index_fields, %$index_date );
		}
	}
	else
	{
		my $value = $dataobj->get_value( $fieldname );
	
		if (defined $value)
		{
			$value = $repo->call( "es_validate_date", $dataobj, $fieldname, $value );

			$index_date = { $fieldname => $value };
			%$index_fields = ( %$index_fields, %$index_date );
		}
	}
	
	return 1;
};

# time type fields
$c->{es_index_type_time} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_time = {};
	
	my $fieldname = $field->name;
	my $multiple = $field->property( "multiple" );
	
	if ($multiple)
	{
		my @index_values;
		
		my $values = $dataobj->get_value( $fieldname );
		foreach my $value (@$values)
		{
			$value = $repo->call( "es_validate_datetime", $dataobj, $fieldname, $value );
			push @index_values, $value;
		}
		
		if (scalar @index_values)
		{
			$index_time = { $fieldname => [ @index_values ] };
			%$index_fields = ( %$index_fields, %$index_time );
		}
	}
	else
	{
		my $value = $dataobj->get_value( $fieldname );
	
		if (defined $value)
		{
			$value = $repo->call( "es_validate_datetime", $dataobj, $fieldname, $value );

			$index_time = { $fieldname => $value };
			%$index_fields = ( %$index_fields, %$index_time );
		}
	}
	
	return 1;
};

# timestamp type fields
$c->{es_index_type_timestamp} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_timestamp = {};
	
	my $fieldname = $field->name;
	my $multiple = $field->property( "multiple" );
	
	if ($multiple)
	{
		my @index_values;
		
		my $values = $dataobj->get_value( $fieldname );
		foreach my $value (@$values)
		{
			$value = $repo->call( "es_validate_datetime", $dataobj, $fieldname, $value );
			push @index_values, $value;
		}
		
		if (scalar @index_values)
		{
			$index_timestamp = { $fieldname => [ @index_values ] };
			%$index_fields = ( %$index_fields, %$index_timestamp );
		}
	}
	else
	{
		my $value = $dataobj->get_value( $fieldname );
	
		if (defined $value)
		{
			$value = $repo->call( "es_validate_datetime", $dataobj, $fieldname, $value );

			$index_timestamp = { $fieldname => $value };
			%$index_fields = ( %$index_fields, %$index_timestamp );
		}
	}
	
	return 1;
};

# integer type fields
$c->{es_index_type_int} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_int = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_int = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_int );
	}
	
	return 1;
};

# float type fields
$c->{es_index_type_float} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_float = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_float = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_float );
	}
	
	return 1;
};

# year type fields
$c->{es_index_type_year} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_year = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_year = { $fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_year );
	}
	
	return 1;
};

# page range type fields
$c->{es_index_type_pagerange} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_pagerange = {};
	
	my $fieldname = $field->name;
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		$index_pagerange = {$fieldname => $value };
		%$index_fields = ( %$index_fields, %$index_pagerange );
	}
	
	return 1;
};


# set type fields
$c->{es_index_type_set} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_set = {};
	
	my $session = $dataobj->get_session();
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	
	my $fieldname = $field->name;
	my $multiple = $field->property( "multiple" );
	
	if ($multiple)
	{
		my @index_values;
		my $values = $dataobj->get_value( $fieldname );
		foreach my $value (@$values)
		{
			my $current_language = $repo->get_langid;

			my @phrases;
			
			foreach my $langid (@{$repo->get_conf( "languages" )})
			{
				$session->change_lang( $langid );
				my $phrase = $session->phrase( $datasetid . "_fieldopt_" . $fieldname . "_" . $value );
				
				push @phrases, {
					lang => $langid,
					phrase => $phrase,
				};
			}
			
			push @index_values, {
				key => $value,
				phrases => [ @phrases ],
			};
		}
		
		$index_set = { $fieldname => [ @index_values ] };
	}
	else
	{
		my $value = $dataobj->get_value( $fieldname );
		if (defined $value)
		{
			my $current_language = $repo->get_langid;
			
			my @phrases;
			
			foreach my $langid (@{$repo->get_conf( "languages" )})
			{
				$session->change_lang( $langid );
				my $phrase = $session->phrase( $datasetid . "_fieldopt_" . $fieldname . "_" . $value );
				
				push @phrases, {
					lang => $langid,
					phrase => $phrase,
				};
			}
			
			$index_set = {
				$fieldname => {
						key => $value,
						phrases => [ @phrases ],
				},
			};
			
			$session->change_lang( $current_language );
		}
	}
	
	%$index_fields = ( %$index_fields, %$index_set );
	
	return 1;
};

# namedset type fields
$c->{es_index_type_namedset} = sub 
{
	my ($repo, $dataobj, $field, $index_fields) = @_;
	
	my $index_namedset = {};
	
	my $session = $dataobj->get_session();
	
	my $fieldname = $field->name;
	my $setname = $field->property( "set_name" );
	my $value = $dataobj->get_value( $fieldname );
	
	if (defined $value)
	{
		my $current_language = $repo->get_langid;
		
		my @phrases;
		
		foreach my $langid (@{$repo->get_conf( "languages" )})
		{
			$session->change_lang( $langid );
			my $phrase = $session->phrase( $setname . "_typename_" . $value );
			
			push @phrases, {
				lang => $langid,
				phrase => $phrase,
			};
		}
		
		$index_namedset = {
			$fieldname => {
					key => $value,
					phrases => [ @phrases ],
			},
		};
		
		$session->change_lang( $current_language );
	}

	%$index_fields = ( %$index_fields, %$index_namedset );
	
	return 1;
};

#
# 3. Citation
#
# es_title gets different treatment because of multilingual highlighting
# earlier, the citation style was just passed to a single method

$c->{es_index_eprint_citation_es_title} = sub 
{
	my ($repo, $dataobj, $index_citation ) = @_;
	
	my $index;
	
	my $index_languages = { 
		"eng" => 1,
		"deu" => 1,
		"fra" => 1,
		"ita" => 1,
	};
	
	my $languages = $dataobj->get_value( "language_mult" );

	my $xhtml = $repo->xhtml;
	
	my $citation_frag = $dataobj->render_citation_link( "es_title" );
	my $citation = $xhtml->to_xhtml( $citation_frag );
	
	# substitute sentence boundary characters because of highlighting
	$citation =~ s/\./[qqp]/g;
	$citation =~ s/,/[qqc]/g; 
	$citation =~ s/!/[qqx]/g; 
	$citation =~ s/\?/[qqq]/g;
	 
	my $set_default = 1;
	my @arr_es_title_ml;
	foreach my $language (@$languages)
	{
		if (defined $index_languages->{$language})
		{
			$set_default = 0;
			push @arr_es_title_ml, {
				$language => $citation,
			};
		}	
	}
	
	if ($set_default)
	{
		push @arr_es_title_ml, {
			default => $citation,
		};
	}
	
	$index = { es_title => [ @arr_es_title_ml ] };
	%$index_citation = ( %$index_citation, %$index );
	
	return 1;
};


$c->{es_index_eprint_citation_es_contributors} = sub 
{
	my ($repo, $dataobj, $index_citation ) = @_;
	
	my $index = $repo->call( "es_index_eprint_citation", $repo, $dataobj, "es_contributors" );
	
	%$index_citation = ( %$index_citation, %$index );
	
	return 1;
};

$c->{es_index_eprint_citation_es_publication} = sub 
{
	my ($repo, $dataobj, $index_citation ) = @_;
	
	my $index = $repo->call( "es_index_eprint_citation", $repo, $dataobj, "es_publication" );
	
	%$index_citation = ( %$index_citation, %$index );
	
	return 1;
};

# general method for citation index based on citation style
$c->{es_index_eprint_citation} = sub
{
	my ($repo, $dataobj, $style ) = @_;
	
	my $xhtml = $repo->xhtml;
	
	my $citation_frag = $dataobj->render_citation_link( $style );
	my $citation = $xhtml->to_xhtml( $citation_frag );
	
	# substitute sentence boundary characters because of highlighting
	$citation =~ s/\./[qqp]/g;
	$citation =~ s/,/[qqc]/g; 
	$citation =~ s/!/[qqx]/g; 
	$citation =~ s/\?/[qqq]/g;
	
	my $index = { $style => $citation };
	
	return $index;
};


#
# 4. Full text index
#
$c->{es_index_eprint_fulltext} = sub 
{
	my ($repo, $dataobj, $index_fulltext) = @_;
	
	my $index;
	
	my $index_languages = { 
		"eng" => 1,
		"deu" => 1,
		"fra" => 1,
		"ita" => 1,
	};
	
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	return 0 if ($dataset->base_id ne "eprint");
	
	my $languages = $dataobj->get_value( "language_mult" );
	
	my @docs_fulltext;
	
	my $convert = $repo->plugin( "Convert" );
	my $tempdir = File::Temp->newdir();
	
	my @docs = $dataobj->get_all_documents;
	
	return 0 if (scalar @docs == 0);
	
	DOC: foreach my $doc (@docs)
	{
		my $docid = $doc->id;
		my $security = $doc->get_value( "security" );
		my $type = "text/plain";
		my %types = $convert->can_convert( $doc, $type );
		next DOC if !exists $types{$type};
		my $plugin = $types{$type}->{plugin};
		
		my $terms = '';
		FILE: foreach my $fn ($plugin->export( $tempdir, $doc, $type ))
		{
			
			open(my $fh, "<", "$tempdir/$fn") or next FILE;
			sysread($fh, my $buffer, 2 * 1024 * 1024);
			close($fh);
			$terms .= Encode::decode_utf8( $buffer );
		}
		
		my $set_default = 1;
		my @arr_fulltext_ml;
		foreach my $language (@$languages)
		{
			if (defined $index_languages->{$language})
			{
				$set_default = 0;
				push @arr_fulltext_ml, {
					$language => $terms,
				};
			}
		}
		if ($set_default)
		{
			push @arr_fulltext_ml, {
				default => $terms,
			};
		}
		
		push @docs_fulltext, { 
			docid => $docid, 
			fulltext => [ @arr_fulltext_ml ],
			security => $security,
		};
	}
	
	$index = { $datasetid => [ @docs_fulltext ] };
	
	%$index_fulltext = %$index;
	
	return 1;
};

#
# 5. Document data
#
$c->{es_index_eprint_documentdata} = sub 
{
	my ($repo, $dataobj, $index_documentdata) = @_;
	
	my $index;
	my @docs_index;	
	
	my $dataset = $dataobj->dataset;
	my $datasetid = $dataset->base_id;
	return 0 if ($dataset->base_id ne "eprint");
	
	my @docs = $dataobj->get_all_documents;
	
	return 0 if (scalar @docs == 0);
	
	foreach my $doc (@docs)
	{
		my $date_embargo = $doc->get_value( "date_embargo" );
		if (defined $date_embargo)
		{
			$date_embargo = $repo->call( "es_validate_datetime", $dataobj, "date_embargo", $date_embargo );
		}
		
		push @docs_index, {
			docid => $doc->id,
			content => $doc->get_value( "content" ),
			date_embargo => $date_embargo,
			format => $doc->get_value( "format" ),
			formatdesc => $doc->get_value( "formatdesc" ),
			license => $doc->get_value( "license" ),
			security => $doc->get_value( "security" ),
		};
	}

	$index = { $datasetid => [ @docs_index ] };
	
	%$index_documentdata = %$index;
	
	return 1;
};

#
# 6. Aggregations
# 

# Publication year
$c->{es_index_agg_eprint_pubyear} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $index_pubyear = {};

	my $value = $dataobj->get_value( "date" );

	if (defined $value)
	{
		my ( $pubyear ) = EPrints::Time::split_value( $value );
		$index_pubyear = { 'agg_pubyear_key' => $pubyear };

		%$index_aggregations = ( %$index_aggregations, %$index_pubyear );
	}
	
	return 1;	
};

# Publication type
$c->{es_index_agg_eprint_pubtype} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $session =  $dataobj->{session};
	
	my $value = $dataobj->get_value( "type" );
	
	my $current_language = $repo->get_langid;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		$session->change_lang( $langid );
		my $phrase = $session->phrase( "eprint_typename_" . $value );
		
		my $index_pubtype = { 'agg_pubtype_' . $langid => $phrase };
		%$index_aggregations = ( %$index_aggregations, %$index_pubtype );
	}
	
	$session->change_lang( $current_language );
	
	return 1;
};

# Has fulltext
$c->{es_index_agg_eprint_hasfulltext} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $session =  $dataobj->{session};
	
	my $value = $dataobj->get_value( "full_text_status" );
	
	my $current_language = $repo->get_langid;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		$session->change_lang( $langid );
		
		my $phrase;
		if ($value eq "public" || $value eq "restricted")
		{
			$phrase = $session->phrase( "es_agg_hasfulltext_yes" );
		}
		else
		{
			$phrase = $session->phrase( "es_agg_hasfulltext_no" );
		}
		
		my $index_hasfulltext = { 'agg_hasfulltext_' . $langid => $phrase };
		%$index_aggregations = ( %$index_aggregations, %$index_hasfulltext );
	}
		
	return 1;	
};

# Access rights
$c->{es_index_agg_eprint_accessrights} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $session =  $dataobj->{session};
	
	my $value = $dataobj->get_value( "access_rights" );
	
	my $current_language = $repo->get_langid;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		$session->change_lang( $langid );
		my $phrase = $session->phrase( "es_agg_access_rights_" . $value );
		
		my $index_accessrights = { 'agg_accessrights_' . $langid => $phrase };
		%$index_aggregations = ( %$index_aggregations, %$index_accessrights );
	}
	
	$session->change_lang( $current_language );
	
	return 1;
};

# Creator/editor/examiner names
$c->{es_index_agg_eprint_name} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $index_name = {};
	
	my $names;
	
	$names = $repo->call( "es_index_agg_contributors", $dataobj, "creators", $names);
	$names = $repo->call( "es_index_agg_contributors", $dataobj, "editors", $names);
	$names = $repo->call( "es_index_agg_contributors", $dataobj, "examiners", $names);

	if (defined $names && scalar @$names)
	{	
		$index_name = { 'agg_name_key' => [ @$names ] };
		%$index_aggregations = ( %$index_aggregations, %$index_name );
	}
	
	return 1;
};

$c->{es_index_agg_contributors} = sub 
{
	my ($dataobj, $fieldname, $names) = @_;
	
	my $contributors = $dataobj->get_value( $fieldname );
	
	foreach my $contributor (@$contributors)
	{
		my $name = $contributor->{name}->{family};
		
		# filter "et al" and variants thereof
		next if ($name =~ /^et\sal/);
		
		if (defined $contributor->{name}->{given})
		{
			$name = $name . " " . $contributor->{name}->{given};
		}

		my $orcid = $contributor->{orcid};
		if (defined $orcid)
		{
			$name = $name . " (" . $orcid . ")";
		}
		
		push @$names, $name;
	}
	
	return $names;
};

# Affiliations
$c->{es_index_agg_eprint_affiliation} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $index_affiliations = {};
	
	my $affiliations;
	
	$affiliations = $repo->call( "es_index_agg_contributor_affiliations", $dataobj, "creators", $affiliations);
	$affiliations = $repo->call( "es_index_agg_contributor_affiliations", $dataobj, "editors", $affiliations);
	$affiliations = $repo->call( "es_index_agg_contributor_affiliations", $dataobj, "examiners", $affiliations);
	
	if (defined $affiliations && scalar @$affiliations)
	{
		$index_affiliations = { 'agg_affiliation_key' => [ @$affiliations ] };
		%$index_aggregations = ( %$index_aggregations, %$index_affiliations );
	}
	
	return 1;
};

$c->{es_index_agg_contributor_affiliations} = sub
{
	my ($dataobj, $fieldname, $affiliations) = @_;
	
	my $session = $dataobj->{session};
	
	my $contributors = $dataobj->get_value( $fieldname );
	
	foreach my $contributor (@$contributors)
	{	
		if (defined $contributor->{affiliation_ids})
		{
			my $afids = $contributor->{affiliation_ids};
			my @affil_ids = split( /\|/, $afids );
			
			foreach my $affil_id (@affil_ids)
			{
				my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $affil_id );
				next if (!defined $affilobj);
				my $org = $affilobj->get_value( "name" );
				my $city = $affilobj->get_value( "city" );
				my $country = $affilobj->get_value( "country" );
                
				my $affiliation = $org;
				$affiliation .= ", " . $city if (defined $city);
				$affiliation .= ", " . $country if (defined $country);
				
				push @$affiliations, $affiliation;
			}
		}
	}
	
	return $affiliations;
};

# Dewey
$c->{es_index_agg_eprint_dewey} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		my $classifications = $repo->call( "es_index_agg_classifications", $dataobj, "dewey", $langid );
		
		if (defined $classifications && scalar @$classifications)
		{
			my $index_classifications = { 'agg_dewey_' . $langid  => [ @$classifications ] };
			%$index_aggregations = ( %$index_aggregations, %$index_classifications );
		}
	}

	return 1;
};

# Subject (Communities & Collections)
$c->{es_index_agg_eprint_subject} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		my $classifications = $repo->call( "es_index_agg_classifications", $dataobj, "subjects", $langid );
		
		if (defined $classifications && scalar @$classifications)
		{
			my $index_classifications = { 'agg_subject_' . $langid  => [ @$classifications ] };
			%$index_aggregations = ( %$index_aggregations, %$index_classifications );
		}
	}

	return 1;
};


$c->{es_index_agg_classifications} = sub
{
	my ($dataobj, $fieldname, $langid) = @_;
	
	my $session = $dataobj->{session};
	
	my $classifications;
	my $classification_codes = $dataobj->get_value( $fieldname );
	
	foreach my $classification_code (@$classification_codes)
	{
		my $subject = EPrints::DataObj::Subject->new( $session, $classification_code );
			
		if (defined $subject)
		{
			my $pos = 0;
			my $lang_pos = 0;
			foreach my $lang (@{$subject->{data}->{name_lang}})
			{
				$lang_pos = $pos if ($lang eq $langid);
				$pos++;
			}
				
			my $subject_names = $subject->get_value( "name" );
			
			push @$classifications, $subject_names->[$lang_pos]->{name};	
		}
	}
	
	return $classifications;
};

# Language
$c->{es_index_agg_eprint_language} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $session = $dataobj->{session};
	
	my $current_language = $repo->get_langid;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		$session->change_lang( $langid );
		
		my @languages;
		my $values = $dataobj->get_value( "language_mult" );
		
		foreach my $value (@$values)
		{
			push @languages, $session->phrase( "eprint_fieldopt_language_mult_" . $value );
		}

		if (scalar @languages)
		{
			my $index_language = { 'agg_language_' . $langid  => [ @languages ] };
			%$index_aggregations = ( %$index_aggregations, %$index_language );
		}
	}
	
	$session->change_lang( $current_language );

	return 1;
};

# Journal/Series title
$c->{es_index_agg_eprint_journalseries} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $journalseries;
	my $type = $dataobj->get_value( "type" );
	
	if ($type eq 'article')
	{
		$journalseries = $dataobj->get_value( "publication" );
	}
	elsif ($type eq 'newspaper_article')
	{
		$journalseries = $dataobj->get_value( "newspaper_title" );
	}
	else
	{
		$journalseries = $dataobj->get_value( "series" );
	}
	
	if (defined $journalseries)
	{
		my $index_journalseries = { 'agg_journalseries_key' => $journalseries };
		%$index_aggregations = ( %$index_aggregations, %$index_journalseries );
	}
	
	return 1;
};


#
# Helper methods
#
$c->{es_validate_date} = sub
{
	my ($dataobj, $fieldname, $date) = @_;
	
	# validate the date
	my @t = EPrints::Time::split_value( $date );
		
	$t[1] = 1 if (!defined $t[1]);
	$t[2] = 1 if (!defined $t[2]);
	my $valid = Date::Calc::check_date( $t[0], $t[1], $t[2] );
		
	if (!$valid)
	{
		my $id = $dataobj->id;
		print STDERR "ES indexing: Error in date $date (item id $id, field $fieldname)\n";
			
		$t[0] = 1 if ($t[0] < 1);
		$t[1] = 1 if ($t[1] < 1);
		$t[2] = 1 if ($t[2] < 1);
		$t[2] = 28 if ($t[1] == 2 && $t[2] > 28);
		$t[2] = 30 if ($t[2] > 30);
			
		$date = EPrints::Time::join_value( @t );
		print STDERR "ES indexing: Fixed to date $date\n";
	}
	
	return $date;
};

$c->{es_validate_datetime} = sub
{
	my ($dataobj, $fieldname, $datetime) = @_;
	
	# validate the date
	my @t = EPrints::Time::split_value( $datetime );
		
	$t[1] = 1 if (!defined $t[1]);
	$t[2] = 1 if (!defined $t[2]);
	$t[3] = 0 if (!defined $t[3]);
	$t[4] = 0 if (!defined $t[4]);
	$t[5] = 0 if (!defined $t[5]);
	my $valid_date = Date::Calc::check_date( $t[0], $t[1], $t[2] );
	my $valid_time = Date::Calc::check_time( $t[3], $t[4], $t[5] );
		
	if (!$valid_date || !$valid_time )
	{
		my $id = $dataobj->id;
		print STDERR "ES indexing: Error in date/timestamp $datetime (item id $id, field $fieldname)\n";
		
		# fix date
		$t[0] = 1 if ($t[0] < 1);
		$t[1] = 1 if ($t[1] < 1);
		$t[2] = 1 if ($t[2] < 1);
		$t[2] = 28 if ($t[1] == 2 && $t[2] > 28);
		$t[2] = 30 if ($t[2] > 30);
		
		# fix time
		$t[3] = 0 if ($t[3] < 0);
		$t[3] = 23 if ($t[3] > 23);
		$t[4] = 0 if ($t[4] < 0);
		$t[4] = 59 if ($t[4] > 59);
		$t[5] = 0 if ($t[5] < 0);
		$t[5] = 59 if ($t[5] > 59);
			
		$datetime = EPrints::Time::join_value( @t );
		print STDERR "ES indexing: Fixed to date/timestamp $datetime\n";
	}
	
	$datetime =~ s/\s/T/g;
	
	return $datetime;
};
