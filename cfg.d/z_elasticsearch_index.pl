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
        my $phrase = $session->phrase( $setname . "_typename_" . $value );
      
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
    $index_namedset = { $fieldname => [ @index_values ] };
  }
  elsif (defined $value)
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

# compound type fields (#NB this will call the routines above on the sub fields)
$c->{es_index_type_compound} = sub 
{
  my ($repo, $dataobj, $field, $index_fields) = @_;
  
  foreach my $sub_field (@{$field->property("fields_cache")})
  {
           my $sub_field_type_fn_index = "es_index_type_".$sub_field->type;
     if( $repo->can_call( $sub_field_type_fn_index ) )
     {
       my $ret = $repo->call( $sub_field_type_fn_index, $repo, $dataobj, $sub_field, $index_fields );
     }
  }
  
  return 1;
};

# A single simple index field for full names "John Smith" as well as "John" and "Smith"
$c->{es_index_type_name} = sub 
{
  my ($repo, $dataobj, $field, $index_fields) = @_;

  my @index_values;

  for my $name ( @{$dataobj->get_value($field->name)} )
  {
    my $name_str = $name->{given}." ".$name->{family};
    push @index_values, $name_str;
  }

  my $index_name = { $field->name => [ @index_values ] };
  %$index_fields = ( %$index_fields, %$index_name );
 
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

# Funder
$c->{es_index_agg_eprint_funders} = sub
{
  my ($repo, $dataobj, $index_aggregations) = @_;
  
  my $session =  $dataobj->{session};
  
  for my $funder( @{$dataobj->get_value( "funders" )} ){
    my $index_funder = { 'agg_funders_key' => $funder->{name} };
    %$index_aggregations = ( %$index_aggregations, %$index_funder );
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

# Creator/contributor names
$c->{es_index_agg_eprint_name} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	my $index_name = {};
	

	my $names;
	for my $c ( @{$dataobj->get_value( "creators_name" )} )
	{
		push @$names, $c->{given}." ".$c->{family};
	}
	for my $c ( @{$dataobj->get_value( "contributors_name" )} )
	{
		push @$names, $c->{given}." ".$c->{family};
	}

	if (defined $names && scalar @$names)
	{	
		$index_name = { 'agg_name_key' => [ @$names ] };
		%$index_aggregations = ( %$index_aggregations, %$index_name );
	}
	
	return 1;
};

# Subject
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

# Division
$c->{es_index_agg_eprint_division} = sub
{
	my ($repo, $dataobj, $index_aggregations) = @_;
	
	foreach my $langid (@{$repo->get_conf( "languages" )})
	{
		my $classifications = $repo->call( "es_index_agg_classifications", $dataobj, "divisions", $langid );
		
		if (defined $classifications && scalar @$classifications)
		{
			my $index_classifications = { 'agg_division_' . $langid  => [ @$classifications ] };
			%$index_aggregations = ( %$index_aggregations, %$index_classifications );
		}
	}

	return 1;
};

# Process subject type fields (like subject and division)
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
