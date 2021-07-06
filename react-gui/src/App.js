import React from "react";

import {
  ErrorBoundary,
  Facet,
  SearchProvider,
  WithSearch,
  SearchBox,
  Results,
  PagingInfo,
  ResultsPerPage,
  Paging,
  Sorting
} from "@elastic/react-search-ui";
//import { Layout, SingleSelectFacet } from "@elastic/react-search-ui-views";
import { Layout } from "@elastic/react-search-ui-views";
import "@elastic/react-search-ui-views/lib/styles/styles.css";

import buildRequest from "./buildRequest";
import runRequest from "./runRequest";
import applyDisjunctiveFaceting from "./applyDisjunctiveFaceting";
import buildState from "./buildState";
import ResultView from "./ResultView"; // 2020/10/22/JW Change new Template
//import UZHSearchBox from "./UZHSearchBox"; // 2021/01/27/JW Change new Template
import Loader from 'react-loader-spinner'; // 2020/11/11/JW Loading Wheel for waiting
//import ReRenderHook from "./ReRenderHook"; // 2021/01/26/JW ReDo Render, e.g. Button-Label (de|en)
import UZHExportBox from "./UZHExportBox";
//import UZHExportBox2 from "./UZHExportBox2";
//import ClearSearchBox from "./ClearSearchBox"; // 2021/01/05/JW Reset
//https://discuss.elastic.co/t/search-ui-clear-searchbox-option/242120/3

const config = {
  //debug: true,
  debug: false,
  hasA11yNotifications: true,
  initialState: {
    resultsPerPage: 10
  },
  // ZORA initials
  browser_lang: "",
  
  onResultClick: () => {
    /* Not implemented */
  },
  onAutocompleteResultClick: () => {
    /* Not implemented */
  },
  autocompleteQuery: {
    // Customize the query for autocompleteResults
    results: {
      resultsPerPage: 10,
      result_fields: {
        proxy_title: { snippet: { size: 100, fallback: true  } }
      }
    },
    // Customize the query for autocompleteSuggestions
    suggestions: {
      types: {
        // Limit query to only suggest based on "title" field
        //documents: { fields: ["proxy_title","proxy_citation"] }
        documents: { fields: ["proxy_title"] }
      },
      // Limit the number of suggestions returned from the server
      size: 4
    }
  },
  onAutocomplete: async ({ searchTerm }) => {
   
    const requestBody = buildRequest({ searchTerm });
    requestBody.autocomplete = "true"; // 2021/02/17/jw : flag if full request or autocomplete request, speed up Proxy
    const json = await runRequest(requestBody);
    const state = buildState(json);

    return {
      autocompletedResults: state.results
    };
  },
  onSearch: async state => {
    
   
    const { resultsPerPage } = state;
    const requestBody = buildRequest(state);
    config.requestBody = requestBody;
    const responseJson = await runRequest(requestBody);
    
    /* first we need the configured aggs */
    window.conf_aggs = ["Config Aggs"]; //initial
    window.conf_aggs_gui_order = ["0"]; //initial
    window.conf_aggs_gui_isfilterable = ["false"]; //initial
    window.conf_aggs_gui_label = ["Label"]; //initial

    if (responseJson.conf_aggs) {
      for (let i = 0; i < responseJson.conf_aggs.length; i++) {
        window.conf_aggs[i] = responseJson.conf_aggs[i];
        window.conf_aggs_gui_order[i] = responseJson.conf_aggs_gui_order[i];
        window.conf_aggs_gui_isfilterable[i] = responseJson.conf_aggs_gui_isfilterable[i];
        window.conf_aggs_gui_label[i] = responseJson.conf_aggs_gui_label[i];
      }
    }

    const responseJsonWithDisjunctiveFacetCounts = await applyDisjunctiveFaceting(
      responseJson,
      state,
      // new conf_aggs, 2021/06/23/JW
      window.conf_aggs
    );

    
    // ZORA internals: 
    config.browser_lang = responseJson.browser_lang;
    config.conf_aggs_gui_sort = responseJson.conf_aggs_gui_sort;
    
    config.autocomplete_title = responseJson.label.autocomplete_title;
    config.sortby_label = responseJson.label.sortby;
    config.sort_year_asc = responseJson.label.sort_year_asc;
    config.sort_year_desc = responseJson.label.sort_year_desc;
    config.relevance_label = responseJson.label.relevance;
    config.export_label = responseJson.label.export;
    config.pageinfo_1_label = responseJson.label.pageinfo_1;
    config.pageinfo_2_label = responseJson.label.pageinfo_2;
    config.pageinfo_3_label = responseJson.label.pageinfo_3;
    config.show_label = responseJson.label.show;
    config.reset_filter_label = responseJson.label.reset_filter;
    config.simple_search_label = responseJson.label.simple_search;
    config.no_results_label = responseJson.label.no_results;

    //Export Plugins
    config.export_plugins = ["Export"];  
    config.export_plugins_name = ["Export"];  
    config.export_plugins_mimetype = ["Export"];  
    config.export_plugins_filename = ["Export"];  

    if (responseJson.export_plugins) {
      for (let i = 0; i < responseJson.export_plugins.length; i++) {
        config.export_plugins[i+1] = responseJson.export_plugins[i];
        config.export_plugins_name[i+1] = responseJson.export_plugins_name[i];
        config.export_plugins_mimetype[i+1] = responseJson.export_plugins_mimetype[i];
        config.export_plugins_filename[i+1] = responseJson.export_plugins_filename[i];
      }
    }
    
    return buildState(responseJsonWithDisjunctiveFacetCounts, resultsPerPage);
  }
};

export default function App() {
  return ( 
    <SearchProvider config={config}>
      <WithSearch mapContextToProps={({wasSearched, isLoading, searchTerm, totalResults}) => ({wasSearched, isLoading, searchTerm, totalResults})}>
        {({ wasSearched, isLoading, searchTerm, totalResults }) => (
          <div className="App col-md-offset-0 col-lg-12 col-md-12 col-sm-12 col-xs-8">
            {(window.location.href.includes("/search")) && (
            <div>           
            <ErrorBoundary>
              <Layout
                header={
                  <div>
                    <SearchBox
                      // inputProps={{ placeholder: config.searchbox_placeholder }}
                      // change to var in eprints template (de/en) for initial setting
                      inputProps={{ 
                        placeholder: window.label_searchbox_placeholder,
                        //value: window.label_searchbutton
                        //buttonProps={{ value: window.label_searchbutton }}
                      }}
                      autocompleteMinimumCharacters={3}
                      autocompleteResults={{
                        // "proxy_uri" change from direct link on eprint to re-search on proxy_title => no linkTarget: "_blank"
                        //linkTarget: "_blank",
                        // later or never: sectionTitle
                        //sectionTitle: "Results",
                        titleField: "proxy_title",
                        urlField: "proxy_uri",
                        shouldTrackClickThrough: true,
                        clickThroughTags: ["test"]
                      }}
                      autocompleteSuggestions={true}           
                      onSubmit={searchTerm => {
                        window.location.href="/search/?q="+searchTerm;
                      }}
                      debounceLength={3}
                    />
                    <ul id="search_more_panel">
                      <li><a href="/search">{window.label_reset_all}</a></li>
                      <li><a href="/cgi/search/advanced">{window.label_advanced_search}</a></li>
                      <li><a href="/help">{window.label_help}</a></li>
                    </ul>
                  </div>
                }
                sideContent={
                  (totalResults > 0) && (
                  <div>
                    {(totalResults > 0) && (config.browser_lang !== "" && ( 
                      <div id="reset_filter" class="button btn btn-primary"><a href={"/search/?q=" + searchTerm}>{config.reset_filter_label}</a></div> 
                    ))}
                      {window.conf_aggs.map(function(object, i){
                        // language aggs
                        if (object.endsWith("_"+config.browser_lang))  {
                          if (window.conf_aggs_gui_isfilterable[i] === "true") {
                            return (
                              <Facet 
                                field={object}
                                label={window.conf_aggs_gui_label[i]}
                                filterType="any" 
                                isFilterable={true}
                                searchPlaceholder={"Filter "+window.conf_aggs_gui_label[i]}
                              />
                            );
                          } else if (window.conf_aggs_gui_isfilterable[i] === "false") {
                            return (
                              <Facet 
                                field={object}
                                label={window.conf_aggs_gui_label[i]}
                                filterType="any" 
                              />
                            );
                          }
                        } // end of language agg
                        // key aggs
                        if (object.endsWith("_key"))  {
                          if (window.conf_aggs_gui_isfilterable[i] === "true") {
                            return (
                              <Facet 
                                field={object}
                                label={window.conf_aggs_gui_label[i]}
                                filterType="any" 
                                isFilterable={true}
                                searchPlaceholder={"Filter "+window.conf_aggs_gui_label[i]}
                              />
                            );
                          } else if (window.conf_aggs_gui_isfilterable[i] === "false") {
                            return (
                              <Facet 
                                field={object}
                                label={window.conf_aggs_gui_label[i]}
                                filterType="any" 
                              />
                            );
                          }
                        } // end of key agg
                        return null; //code fix
                      })}
                  </div>
                  )
                }
                bodyContent={
                  <div>
                    {isLoading && 
                      <div className="App-loader">         
                        <Loader type="ThreeDots" color="#3a56e4" height="150" width="150" />
                      </div>
                    }
                    {!isLoading && (totalResults > 0) && (
                      <Results
                        titleField="proxy_title"
                        languageField="language"
                        journalField="journal"
                        pubtype_enField="pubtype_en"
                        citationField="proxy_citation"
                        shouldTrackClickThrough={true}
                        resultView={ResultView}
                      />
                    )}          
                    {!isLoading && wasSearched && (totalResults <= 0) && (
                      <div>
                        <span class='fa-stack fa-lg'> 
                          <i class='fa fa-binoculars fa-stack-1x'></i> 
                          <i class='fa fa-ban fa-stack-2x text-danger'></i>
                        </span>
                        {config.no_results_label}
                      </div>
                    )}  
                  </div>
                } //resultView={ResultView}
                bodyHeader={
                  <React.Fragment>
                    {wasSearched && (totalResults > 0) && (
                      <Sorting
                        sortOptions={[
                          {
                            name: config.relevance_label,
                            value: "",
                            direction: ""
                          },
                          {
                            name: config.sort_year_asc,
                            value: config.conf_aggs_gui_sort,
                            direction: "asc"
                          },
                          {
                            name: config.sort_year_desc,
                            value: config.conf_aggs_gui_sort,
                            direction: "desc"
                          }
                        ]}
                      />
                    )}
                    
                    {(totalResults > 0) && (config.browser_lang !== "" && ( 
                      <UZHExportBox export={config.export_plugins} 
                                     export_name={config.export_plugins_name} 
                                     export_mimetype={config.export_plugins_mimetype} 
                                     export_filename={config.export_plugins_filename} 
                                     request={config.requestBody} />
                    ))}
                    
                    {wasSearched && (totalResults > 0) && <PagingInfo pi1={config.pageinfo_1_label} pi2={config.pageinfo_2_label} pi3={config.pageinfo_3_label} />}
                    
                    {wasSearched && (totalResults > 0) && <ResultsPerPage options={[10, 50, 100]} label={config.show_label} />}
                    
                  </React.Fragment>
                }
                bodyFooter={(totalResults > 0) && <Paging />}
              />
             </ErrorBoundary>
             </div>
              )
            }

            {(!window.location.href.includes("/search")) && (
                  <div>
                   <SearchBox
                      // inputProps={{ placeholder: config.searchbox_placeholder }}
                      // change to var in eprints template (de/en) for initial setting
                      inputProps={{ 
                        placeholder: window.label_searchbox_placeholder,
                        //value: window.label_searchbutton
                        //buttonProps={{ value: window.label_searchbutton }}
                      }}
                      autocompleteMinimumCharacters={3}
                      autocompleteResults={{
                        // "proxy_uri" change from direct link on eprint to re-search on proxy_title => no linkTarget: "_blank"
                        //linkTarget: "_blank",
                        // later or never: sectionTitle
                        //sectionTitle: "Results",
                        titleField: "proxy_title",
                        urlField: "proxy_uri",
                        shouldTrackClickThrough: true,
                        clickThroughTags: ["test"]
                      }}
                      autocompleteSuggestions={true}
                       // Test JW: if not landing page redirect to landing page                
                      onSubmit={searchTerm => {
                        window.location.href="/search/?q="+searchTerm;
                      }}
                      debounceLength={3}
                    />
                  </div>
              )
            }
          </div>
        )}
      </WithSearch>
    </SearchProvider>
  );
}

/* old stuff 
    config.agg_pubyear_key_label = responseJson.label.agg_pubyear_key;
    config.agg_name_key_label = responseJson.label.agg_name_key;
    config.agg_subject_label = responseJson.label.agg_subject;
    config.agg_pubtype_label = responseJson.label.agg_pubtype;
    config.agg_hasfulltext_label = responseJson.label.agg_hasfulltext;
    config.agg_accessrights_label = responseJson.label.agg_accessrights;
    config.agg_language_label = responseJson.label.agg_language;
    config.agg_dewey_label = responseJson.label.agg_dewey;
    config.agg_journalseries_key_label = responseJson.label.agg_journalseries_key;
    config.agg_affiliation_key_label = responseJson.label.agg_affiliation_key;
*/