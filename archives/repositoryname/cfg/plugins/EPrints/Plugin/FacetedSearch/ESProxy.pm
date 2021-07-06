######################################################################
#
#  FacetedSearch::ESProxy plugin - handle GUI-ZORA-ElasticSearchServer
#
######################################################################
#
#  Copyright 2020-2021 University of Zurich. All Rights Reserved.
#
#  Jens Witzel
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


package EPrints::Plugin::FacetedSearch::ESProxy;

use warnings;
use strict;
use Search::Elasticsearch;
use FileHandle;
use Encode;
use utf8;

use EPrints;

use lib '/usr/local/eprints/perl_cpan/lib/perl5';
use CGI;
use CGI::IDS;
use Data::Dumper;

use JSON;

use base 'EPrints::Plugin';

# flag if full request or autocomplete request only
my $autocomplete_flag = "false";

# flag & export plugin if export is requested
my $export_plugin_selected = "false";

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "FacetedSearch::ESProxy";
	$self->{visible} = "all";

	return $self;
}

#
# get JSON browser request
#
sub get_browser_request {
        my ($self, $session) = @_;

        # maximum JSON read limi
        our $MAXSIZE    = 1 * 1024 * 1024;

        my $jrb;
        $session->get_request->read( $jrb, $MAXSIZE + 1 );

        EPrints->abort("JSON read limit reached") if length($jrb) > $MAXSIZE;
        EPrints->abort("No JSON request") if length($jrb) <= 0;

        return JSON::decode_json($jrb);
}

#
# add facet labels - phrases for each language
#
sub add_facet_labels {
	my ($self, $session,$result) = @_;

	#extra	
	$result->{'label'}->{'sortby'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_sortby") );
	$result->{'label'}->{'autocomplete_title'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_autocomplete_title") );
	$result->{'label'}->{'help'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_help") );
	$result->{'label'}->{'no_results'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_noresults") );
	$result->{'label'}->{'simple_search'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_simple_search") );
	$result->{'label'}->{'advanced_search'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_advanced_search") );
	$result->{'label'}->{'reset_all'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_reset_all") );
	$result->{'label'}->{'reset_filter'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_reset_filter") );
	$result->{'label'}->{'searchbox_placeholder'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_placeholder") );
	$result->{'label'}->{'relevance'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_relevance") );
	$result->{'label'}->{'pageinfo_1'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_pageinfo_1" ));
	$result->{'label'}->{'pageinfo_2'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_pageinfo_2" ));
	$result->{'label'}->{'pageinfo_3'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_pageinfo_3" ));
	$result->{'label'}->{'export'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_export" ));
	$result->{'label'}->{'show'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_show" ));
	$result->{'label'}->{'sort_year_asc'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_year_asc") );
	$result->{'label'}->{'sort_year_desc'} =
  	EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase("fs_year_desc") );

    	return $result;
}

#
# check and return highlighted fields
#
sub exist_highlight {
	my ($self, $session, $highlight, $field) = @_;

        if ( (defined $highlight->{$field}[0]) && ($highlight->{$field}[0] ne "") )
        {
                return $highlight->{$field}[0];
        }

        return "";
}

#
# check and return highlighted fields with language extension
#
sub exist_highlight_lang {
	my ($self, $session, $highlight, $field) = @_;

        # eng, deu, fra, ita, default
 	my $highlight_languages = $session->get_repository->get_conf( "es", "nested_languages" );
        foreach my $lang (@$highlight_languages) {
                my $tmp_field = $field.".".$lang;
                if ( (defined $highlight->{$tmp_field}[0]) && ($highlight->{$tmp_field}[0] ne "") )
                {
                        return $highlight->{$tmp_field}[0];
                }
        }
        return "";
}

#
# check and return fields with language extension
#
sub exist_field_lang {
	my ($self, $session, $field) = @_;

        # e.g. eng, deu, fra, ita, default
 	my $languages = $session->get_repository->get_conf( "es", "nested_languages" );
        foreach my $lang (@$languages) {
                if ( (defined $field->{$lang}) && ($field->{$lang} ne "") )
                {
                        return $field->{$lang};
                }
        }
        return "";
}

#
# modify browser request
#
sub modify_request
{
        my ($self, $session, $json_request_browser) = @_;

	my $lang = $session->get_langid();

        # ES7: give us more than 10.000 results
        # https://www.elastic.co/guide/en/elasticsearch/reference/current/breaking-changes-7.0.html#hits-total-now-object-search-response
        $json_request_browser->{track_total_hits} = "true";

        # check if autosuggest request or full request
        if ( defined $json_request_browser->{autocomplete}
        && ( $json_request_browser->{autocomplete} eq "true" ) )
        {
		delete $json_request_browser->{autocomplete};
		# do not need aggs. ijust need highlight, query etc. only
		delete $json_request_browser->{aggs};
		$autocomplete_flag = "true";
        }
	else
	{
		$autocomplete_flag = "false";
	}

        # check if export_plugin_selected
        if ( defined $json_request_browser->{export_plugin_selected})
        {
		$export_plugin_selected = $json_request_browser->{export_plugin_selected};
		delete $json_request_browser->{export_plugin_selected};
        }
	else
        {
		$export_plugin_selected = "false";
        }

	if (check_ids($json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}))
        {
               $json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query} = "";
        }

	# a+b) replace unwanted special chars like "/" to "\\/", same with "[]{}<>"; later: beware this string: "3874384""/&%
	# b) replace ":" to " " in query, except ALIASES
        # c) expand Prefixes in query; only ALIASES expand=1 in z_elasticsearch_aliases.pl; example: let "TI:" => "TI.\*:"
        #    analyse Prefix ranges, example: PY:2015-2020; PY:2015-; PY:-2015
        #    analyse Prefix ranges, example: PY:[2015-2020]; PY:{2015 TO 2020]; PY:[2015 TO 2020}
	
	my $conf_aliases = $session->get_repository->get_conf( "es", "aliases", "eprint" );

	# AGGS from config z_elasticsearch_aggregations.pl to _source: key or language (de, en)
	# AGGS from config z_elasticsearch_aggregations.pl to aggs: size, field, order
	my $conf_aggs = $session->get_repository->get_conf( "es", "aggs");
        foreach my $conf_agg (@$conf_aggs) {
                my $name = $conf_agg->{name};
                my $type = $conf_agg->{type};
                my $size = $conf_agg->{size};
		if ( $type eq "key" )
		{
			my $agg_name = "agg_".$name."_key";
			my $agg_field = "agg_".$name."_key";
			$json_request_browser->{aggs}->{$agg_name}->{terms}->{size} = $size;	
			$json_request_browser->{aggs}->{$agg_name}->{terms}->{field} = $agg_field;	
       			if ((defined $conf_agg->{order}) && ($conf_agg->{order} ne ""))
			{
                		my $agg_order = $conf_agg->{order};
				$json_request_browser->{aggs}->{$agg_name}->{terms}->{order} = $agg_order;
			}
			push $json_request_browser->{_source}, $agg_name;	
		}
		if ( $type eq "language" )
		{
			my $agg_name_de = "agg_".$name."_de";
			my $agg_name_en = "agg_".$name."_en";
			my $agg_field_de = "agg_".$name."_de";
			my $agg_field_en = "agg_".$name."_en";
			$json_request_browser->{aggs}->{$agg_name_de}->{terms}->{size} = $size;	
			$json_request_browser->{aggs}->{$agg_name_de}->{terms}->{field} = $agg_field_de;	
			$json_request_browser->{aggs}->{$agg_name_en}->{terms}->{size} = $size;	
			$json_request_browser->{aggs}->{$agg_name_en}->{terms}->{field} = $agg_field_en;	
       			if ((defined $conf_agg->{order}) && ($conf_agg->{order} ne ""))
			{
                		my $agg_order = $conf_agg->{order};
				$json_request_browser->{aggs}->{$agg_name_de}->{terms}->{order} = $agg_order;
				$json_request_browser->{aggs}->{$agg_name_en}->{terms}->{order} = $agg_order;
			}
			push $json_request_browser->{_source}, $agg_name_de;	
			push $json_request_browser->{_source}, $agg_name_en;	
		}
        }
	# AGGS from config z_elasticsearch_aggregations.pl to _source end

	if ( defined $json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query} )
	{
		my @split_queries = split /\s+/, $json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query};

		my $gotcha = 0;
		foreach my $query_part(@split_queries) {
			# a)
			$query_part =~ s/\//\\\//g;

			# c)
			foreach my $ca (@$conf_aliases)
			{
        			if ( index($query_part, "$ca->{alias}:") != -1 )
        			{
					$gotcha++;
					if ( $ca->{expand} eq "1")
					{
               					$query_part =~ s/$ca->{alias}:/$ca->{alias}\.\\*:/g;
					}
					if ( $ca->{range} eq "1")
        				{
						if ( index($query_part, "-") != -1 )
						{
							my $colon = index($query_part, ":");
							my $minus = index($query_part, "-");
							my $range_from = substr $query_part, ($colon+1), ($minus-($colon+1));
							my $range_to = substr $query_part, ($minus+1);
							if (length($range_from) eq 0)
							{
								$range_from ="*";
							}
							if (length($range_to) eq 0)
							{
								$range_to ="*";
							}
							$query_part = "$ca->{alias}:[$range_from TO $range_to]";
						}
					}
        			}
			}
		}

		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query} = join( ' ', @split_queries );

		# b)
		if (!$gotcha)
		{
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\:/ /g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\[/\\\[/g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\]/\\\]/g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\{/\\\}/g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\}/\\\}/g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\>/\\\>/g;
               		$json_request_browser->{query}->{bool}->{must}[0]->{query_string}->{query}  =~ s/\</\\\</g;
		}
	}

        return $json_request_browser;
}

#
# enrich ES results, add ZORA metadata and phrases
#
sub modify_result {
	my ($self, $session, $plugin, $result) = @_;

	my $hits_ref     = $result->{hits}->{hits};
	my $hits_counter = scalar(@$hits_ref);

	# Browser Session: language choice of user
	my $lang = $session->get_langid();
	$result->{browser_lang} = $lang;

	if ( $hits_counter gt 0 ) {

		my @ids = [];
		my @ids_title = [];

        if ( $autocomplete_flag eq "true" )
        {
		for my $i ( 0 .. $hits_counter - 1 ) {
			# list of eprint IDs
			$ids[$i] =  $result->{hits}->{hits}[$i]->{_source}->{id};
			my $es_eprint = EPrints::DataObj::EPrint->new( $session, $ids[$i]);

			# prepare zora title
			$ids_title[$i] = $es_eprint->get_value('title');

			#highlight nested title or not
			my $tmp_highlight = "";
			$tmp_highlight = $plugin->exist_highlight_lang($session,$result->{hits}->{hits}[$i]->{highlight},"metadata.eprint.title");

			if ( $tmp_highlight ne "" )
			{
				#$tmp_highlight = remask_boundary_character($tmp_highlight);
				$result->{hits}->{hits}[$i]->{_source}->{proxy_title} = $tmp_highlight;

				#add highlight for autocomplete - note the brackets [] !!!!
				#$result->{hits}->{hits}[$i]->{highlight}->{proxy_title} = [remask_boundary_character($tmp_highlight)];
				$result->{hits}->{hits}[$i]->{highlight}->{proxy_title} = [$tmp_highlight];
			}
			else
			{
				# add title from zora
				$result->{hits}->{hits}[$i]->{_source}->{proxy_title} = $ids_title[$i];
			}

			delete $result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_title};
			delete $result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_contributors};

			# add link for autocomplete
			#
			# 2021/01/25/jw: change from direct link on eprint to re-search on proxy_title, beware of special chars (!)
			#$result->{hits}->{hits}[$i]->{_source}->{proxy_uri} = "http://www.zora.uzh.ch/".$result->{hits}->{hits}[$i]->{_source}->{id};
			my $save_ids_title = $ids_title[$i];	
			$save_ids_title =~ s/\W/ /g; #remove all except alphanum
			$result->{hits}->{hits}[$i]->{_source}->{proxy_uri} = $session->config( "http_url" )."/search/?q=".$save_ids_title;
		}
        } # autocomplete
	else
	{ # regular search
		my $user =  $session->current_user;

		$result = $plugin->add_gui_aggs_back($session,$result);

		for my $i ( 0 .. $hits_counter - 1 ) {
			# list of eprint IDs
			$ids[$i] =  $result->{hits}->{hits}[$i]->{_source}->{id};
			my $es_eprint = EPrints::DataObj::EPrint->new( $session, $ids[$i]);

			# prepare zora title
			$ids_title[$i] = $es_eprint->get_value('title');

			#highlight nested title or not
			my $tmp_highlight = "";
			$tmp_highlight = $plugin->exist_highlight_lang($session,$result->{hits}->{hits}[$i]->{highlight},"metadata.eprint.title");

			if ( $tmp_highlight ne "" )
			{
				#$tmp_highlight = remask_boundary_character($tmp_highlight);
				$result->{hits}->{hits}[$i]->{_source}->{proxy_title} = $tmp_highlight;

				#add highlight for autocomplete - note the brackets [] !!!!
				#$result->{hits}->{hits}[$i]->{highlight}->{proxy_title} = [remask_boundary_character($tmp_highlight)];
				$result->{hits}->{hits}[$i]->{highlight}->{proxy_title} = [$tmp_highlight];
			}
			else
			{
				# add title from zora
				$result->{hits}->{hits}[$i]->{_source}->{proxy_title} = $ids_title[$i];
			}

			#highlight nested citations or not

			# 1. title
			$tmp_highlight = $plugin->exist_highlight_lang($session,$result->{hits}->{hits}[$i]->{highlight},"citation.eprint.es_title");
			if ( $tmp_highlight ne "" )
			{
				$tmp_highlight = remask_boundary_character($tmp_highlight);
				$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remove_link_highlight($tmp_highlight);
			}
			else
			{
				$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remask_boundary_character($plugin->exist_field_lang($session,$result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_title}[0]));
			}
			delete $result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_title};


			# 2.+3. docs = oa-lock & img
			$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= $es_eprint->render_citation_link("es_docs");

			# 4. contributors
			$tmp_highlight = $plugin->exist_highlight($session,$result->{hits}->{hits}[$i]->{highlight},"citation.eprint.es_contributors");
			if ( $tmp_highlight ne "" )
			{
				$tmp_highlight = remask_boundary_character($tmp_highlight);
				$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remove_link_highlight($tmp_highlight);
			}
			else
			{
				$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remask_boundary_character($result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_contributors});
			}
			delete $result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_contributors};

			# 5. publication
			$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remask_boundary_character($result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_publication});

			#if ( $tmp_highlight ne "" )
			#{
			#	$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= remove_link_highlight($tmp_highlight);
			#}
			#else
			#{
			#	$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .=
			#		$result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_publication};
			#}
			delete $result->{hits}->{hits}[$i]->{_source}->{citation}->{eprint}->{es_publication};

			# 6. nested abstact or not
			$tmp_highlight = $plugin->exist_highlight_lang($session,$result->{hits}->{hits}[$i]->{highlight},"metadata.eprint.abstract");
			if ( $tmp_highlight ne "" )
			{
				$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= "<dd class='dreiklang_abstract'> [...] ".$tmp_highlight." [...]</dd>";
			}
			# 7. nested fulltext or not
			# 7a. find most open security (loop all over)
			if ( defined $result->{hits}->{hits}[$i]->{_source}->{fulltext}->{eprint} )
			{
				my $doc_array = $result->{hits}->{hits}[$i]->{_source}->{fulltext}->{eprint};
				my $doc_count = scalar(@$doc_array);
				my $doc_top_security = "validuser"; # secure it first
				for my $j ( 0 .. $doc_count - 1 ) {
        		   		if ( (defined $result->{hits}->{hits}[$i]->{_source}->{fulltext}->{eprint}[$j]->{security}) && ( $result->{hits}->{hits}[$i]->{_source}->{fulltext}->{eprint}[$j]->{security} ne "") )
					{
						if ($result->{hits}->{hits}[$i]->{_source}->{fulltext}->{eprint}[$j]->{security} eq "public")
						{
							$doc_top_security = "public"; # choose most open
						}
					}
				}
			
				# 7b. show fulltext on security status
        			if ( (defined $doc_top_security) && ( $doc_top_security ne "") )
        			{
					# proceed: due to copyright only show fulltext on public docs or show for logged in users
        				if (($doc_top_security eq "public") ||
				    	(($doc_top_security eq "validuser") &&
				     	(defined $user)))
					{
						$tmp_highlight = $plugin->exist_highlight_lang($session,$result->{hits}->{hits}[$i]->{highlight},"fulltext.eprint.fulltext");
						if ( $tmp_highlight ne "" )
						{
							$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} .= "<dd class='dreiklang_fulltext'> [...] ".$tmp_highlight." [...]</dd>";
						}
					}
	        		}
			}

			# remove highlight in MathJax
			$result->{hits}->{hits}[$i]->{_source}->{proxy_citation} = remove_math_highlight($result->{hits}->{hits}[$i]->{_source}->{proxy_citation});

			#add link for autocomplete
			#
			# 2021/01/25/jw: change from direct link on eprint to re-search on proxy_title, beware of special chars (!)
			#$result->{hits}->{hits}[$i]->{_source}->{proxy_uri} = "http://www.zora.uzh.ch/".$result->{hits}->{hits}[$i]->{_source}->{id};
			my $save_ids_title = $ids_title[$i];	
			$save_ids_title =~ s/\W/ /g; #remove all except alphanum
			$result->{hits}->{hits}[$i]->{_source}->{proxy_uri} = $session->config( "http_url" )."/seach/?q=".$save_ids_title;
		}

		$result = $plugin->add_export($session,$result,@ids);

		if ( $export_plugin_selected ne "false" )
		{
			$result->{export_plugin_selected} = $export_plugin_selected;
		}
	} # regular search

		#$result->{'result_placeholder'} = EPrints::Utils::tree_to_utf8( $session->html_phrase("fs_placeholder") );
	}

    	return $result;
}

#
# do export 
#
sub do_export {
        my ($self, $session, $export_plugin_selected, @ids) = @_;

	my $export_plugin = $session->get_repository->plugin( "Export::".$export_plugin_selected );

	my $filename = "export_" . EPrints::Time::iso_date() . $export_plugin->param( 'suffix' );
        my $plugin_mimetype = $export_plugin->param( 'mimetype' );

        EPrints::Apache::AnApache::header_out(
        	$self->{session}->get_request,
        	"Content-Disposition" => "attachment; filename=$filename"
        );
        EPrints::Apache::AnApache::header_out(
        	$self->{session}->get_request,
        	"Content-Type" => $plugin_mimetype
        );

	my $datasetid = 'archive';
	my $ds = $session->dataset( $datasetid ) ;
	my %arguments = %{$export_plugin->param( "arguments" )};
	if( !defined $ds )
	{
		print STDERR "Unknown Dataset ID: $datasetid\n";
		$session->terminate;
		exit 1;
	}

	my $list = EPrints::List->new(
		session => $session,
		dataset => $ds,
		ids=>\@ids );

	$export_plugin->output_list( list=>$list, fh=>*STDOUT, %arguments );

        return ;
}

#
# add export plugins
#
sub add_export {
        my ($self, $session, $result, @ids) = @_;

	my $conf_export_plugins = $session->get_repository->get_conf( "es", "export_plugins" );

	my @aa; # plugin plugin
	my @bb; # plugin label
	my @cc; # plugin mimetype
	my @dd; # plugin filename
	my @ee; # plugin order

	my $i=0;
	foreach my $p (@$conf_export_plugins) {
                my $plugin = $p->{name};
                my $plugin_label = $p->{label};
                my $plugin_mimetype = $session->plugin($plugin)->param("mimetype");
                my $plugin_filename = "zora_export_" . EPrints::Time::iso_date() . $session->plugin($plugin)->param("suffix");
                my $plugin_order = $p->{order};
                my $plugin_vis_level = $p->{vis_level};

		if (($plugin_vis_level eq "all") || ($plugin_vis_level eq $self->_vis_level))
		{
			#without "Export::"
                	$plugin = substr $plugin, 8;
	
        		$aa[$i] = $plugin;
        		$bb[$i] = $plugin_label;
        		$cc[$i] = $plugin_mimetype;
        		$dd[$i] = $plugin_filename;
        		$ee[$i] = $plugin_order;
			$i++;
		}
        }

	# sort all by plugin order from conf
	my @idx = sort { $ee[$a] cmp $ee[$b] } 0 .. $#bb;
	@aa = @aa[@idx];
	@bb = @bb[@idx];
	@cc = @cc[@idx];
	@dd = @dd[@idx];
	@ee = @dd[@idx];

	# result for GUI export-box
        for my $i ( 0 .. (scalar(@aa)) - 1 ) {
        	$result->{'export_plugins'}->[$i] = $aa[$i];
        	$result->{'export_plugins_name'}->[$i] =  $bb[$i];
        	$result->{'export_plugins_mimetype'}->[$i] =  $cc[$i];
        	$result->{'export_plugins_filename'}->[$i] =  $dd[$i];
	}

        return $result;
}

#
# add gui aggs with order/filter on the way back
#
sub add_gui_aggs_back {
        my ($self, $session, $result) = @_;

	# AGGS from config z_elasticsearch_aggregations.pl to result for react
	my $conf_aggs = $session->get_repository->get_conf( "es", "aggs");
	$result->{conf_aggs} = [];
	$result->{conf_aggs_gui_order} = [];
	$result->{conf_aggs_gui_isfilterable} = [];
	$result->{conf_aggs_gui_sort} = "";
	my $conf_aggs_name = [];
	my $conf_aggs_gui_order_array = [];
	my $conf_aggs_gui_isfilterable_array = [];
	my @aa; # conf agg name
	my @bb; # conf agg order
	my @cc; # conf agg isfilterable
	my @dd; # conf agg label , now phrases but later conf!!!

	my $i=0;
        foreach my $conf_agg (@$conf_aggs) {
                my $name = $conf_agg->{name};
                my $type = $conf_agg->{type};
                my $gui_order = $conf_agg->{gui_order};
                my $gui_isfilterable = $conf_agg->{gui_isfilterable};
                my $gui_sort = $conf_agg->{gui_sort};
                my $gui_lable = "fs_agg_".$name;
		if ( $type eq "key" )
		{
			my $agg_name = "agg_".$name."_key";
        		$aa[$i] = "agg_".$conf_agg->{name}."_key";
        		$bb[$i] = $gui_order;
        		$cc[$i] = $gui_isfilterable;
        		$dd[$i] = EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase($gui_lable) );
		}
		if ( $type eq "language" )
		{
			my $agg_name_de = "agg_".$name."_de";
			my $agg_name_en = "agg_".$name."_en";

        		$aa[$i] = "agg_".$conf_agg->{name}."_de";
        		$bb[$i] = $gui_order;
        		$cc[$i] = $gui_isfilterable;
        		$dd[$i] = EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase($gui_lable) );
			$i++;
			$gui_order++;
        		$aa[$i] = "agg_".$conf_agg->{name}."_en";
        		$bb[$i] = $gui_order;
        		$cc[$i] = $gui_isfilterable;
        		$dd[$i] = EPrints::Utils::tree_to_utf8( $self->{session}->html_phrase($gui_lable) );
		}
		$i++;

        	if ( (defined $conf_agg->{gui_sort}) && ($conf_agg->{gui_sort} eq "true") )
        	{
			$result->{conf_aggs_gui_sort} = "agg_".$conf_agg->{name}."_key";
        	}
        }

	# sort all by plugin order from conf
	my @idx = sort { $bb[$a] cmp $bb[$b] } 0 .. $#bb;
	@aa = @aa[@idx];
	@bb = @bb[@idx];
	@cc = @cc[@idx];
	@dd = @dd[@idx];

	# result for gui aggs
        for my $i ( 0 .. (scalar(@aa)) - 1 ) {
        	$result->{conf_aggs}->[$i] = $aa[$i];
        	$result->{conf_aggs_gui_order}->[$i] =  $bb[$i];
        	$result->{conf_aggs_gui_isfilterable}->[$i] =  $cc[$i];
        	$result->{conf_aggs_gui_label}->[$i] =  $dd[$i];
	}


        return $result;
}

sub _get_export_plugins
{
        my( $self ) = @_;

        my %opts =  (
                        type => "Export",
                        #is_advertised => 1,
                        can_accept => "list/eprint",
                        is_visible => $self->_vis_level,
        );

        return $self->{session}->plugin_list( %opts );
}


sub _vis_level
{
        my( $self ) = @_;

        return "staff" if defined $self->{session}->current_user && $self->{session}->current_user->is_staff;

        return "all";
}

#
# remove highlighted terms in links
#
sub remove_link_highlight
{
	my ($link) = @_;

	# <em> in href
	$link =~ s/<a\shref=\"(.*?)<em>(.*?)<\/em>(.*?)\"(.*?)>/<a href="$1$2$3"$4>/g;
	# <em> in title
	$link =~ s/<a(.*?)title=\"(.*?)<em>(.*?)<\/em>(.*?)\"(.*?)>/<a$1title="$2$3$4"$5>/g;

	# a in <em> 
	$link =~ s/<<em>a<\/em>(.*?)>/<a $1>/g;
	$link =~ s/<\/<em>a<\/em>>/<\/a>/g;

	# href in <em> 
	$link =~ s/<a(.*?)<em>href<\/em>(.*?)/<a $1 href$2/g;

	# <em> between every <..> - test
	# 1st try
	#$link =~ s/<(.*?)<em>(.*?)<\/em>(.*?)>/<$1$2$3>/g;

	# 2nd try
	#$link =~ s/<(.*?[^>])<em>(.*?)<\/em>(.*?)>/<$1$2$3>/g;

	# 3rd try
	#$link =~ s/<em>/\[openEMopen\]/g;
	#$link =~ s/<\/em>/\[closeEMclose\]/g;
	#$link =~ s/<(.*?)\[openEMopen\](.*?)\[closeEMclose\](.*?)>/<$1$2$3>/g;
	#$link =~ s/\[openEMopen\]/<em>/g;
	#$link =~ s/\[closeEMclose\]/<\/em>/g;

	return $link;
}

#
# remove highlighted terms in MathJax
#
sub remove_math_highlight
{
	my ($math) = @_;

	$math =~ s/\$(.*?)<em>(.*?)<\/em>(.*?)\$/\$$1$2$3\$/g;

	return $math;
}

#
# re-mask boundary character
#
sub remask_boundary_character
{
	my ($str) = @_;

	$str =~ s/\[qqp\]/./g;
	$str =~ s/\[qqc\]/,/g;
	$str =~ s/\[qqx\]/!/g;
	$str =~ s/\[qqq\]/?/g; 

	return $str;
}

sub check_ids
{
	my ($detection_query) = @_;

	my $conf = $EPrints::SystemSettings::conf;
	my $ids = new CGI::IDS(
    		whitelist_file  => $conf->{base_path} . '/perl_cpan/lib/perl5/CGI/IDS_UZH_whitelist.xml',
    		#disable_filters => [58,59,60,8,67],
    		disable_filters => [58,59,60,8],
	);
	my $query = new CGI;

	# start detection
	my %params = ( 'q' => $detection_query);
	my $impact = $ids->detect_attacks( request => \%params );
	my $error = $ids->get_attacks( request => \%params );
	
	# analyze impact, log but do not inform the attacker
	if ($impact > 0) {
		my $filename_dumper = $conf->{base_path} . '/var/ids.log';
		open(my $fh_dumper, '>>', $filename_dumper) or die "Could not open file '$filename_dumper' !";
		say $fh_dumper "*** Intrusion Detection (IDS) via $0";
		say $fh_dumper "IP: ".$ENV{REMOTE_ADDR};
		say $fh_dumper "DATE: ". localtime();
		say $fh_dumper "IMPACT: ". $impact;
        	my $attacks = $ids->get_attacks();
            	foreach my $attack (@$attacks) {
               		say $fh_dumper "FILTERS MATCHED: ".   join("\n", map {"#$_: " . $ids->get_rule_description(rule_id => $_)} @{$attack->{matched_filters}});
               		say $fh_dumper "TAGS MATCHED: ".   join(",", @{$attack->{matched_tags}});
               		say $fh_dumper "VALUE: ". $detection_query;
            	}
		say $fh_dumper "\n";
		close $fh_dumper;
		return 1;
	}
	return 0;
}

1;

=head1 AUTHOR

Jens Witzel <jens.witzel@uzh.ch>, Zentrale Informatik, University of Zurich

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2020- University of Zurich.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of ZORA based on EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

