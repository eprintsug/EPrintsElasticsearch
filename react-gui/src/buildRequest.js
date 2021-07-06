import buildRequestFilter from "./buildRequestFilter";

function buildFrom(current, resultsPerPage) {
  if (!current || !resultsPerPage) return;
  return (current - 1) * resultsPerPage;
}

function buildSort(sortDirection, sortField) {
  if (sortDirection && sortField) {
    //return [{ [`${sortField}.keyword`]: sortDirection }];
    return [{ [`${sortField}`]: sortDirection }]; // JW 2020/10/22 Keyword Change
  }
}

/*
function buildMatch(searchTerm) {
  return searchTerm
    ? {
        multi_match: {
          query: searchTerm,
          fields: [ "metadata.eprint.title.*", "agg_pubyear_key"]
        }
      }
    : { match_all: {} };
}
*/

/*

  Converts current application state to an Elasticsearch request.

  When implementing an onSearch Handler in Search UI, the handler needs to take the
  current state of the application and convert it to an API request.

  For instance, there is a "current" property in the application state that you receive
  in this handler. The "current" property represents the current page in pagination. This
  method converts our "current" property to Elasticsearch's "from" parameter.

  This "current" property is a "page" offset, while Elasticsearch's "from" parameter
  is a "item" offset. In other words, for a set of 100 results and a page size
  of 10, if our "current" value is "4", then the equivalent Elasticsearch "from" value
  would be "40". This method does that conversion.

  We then do similar things for searchTerm, filters, sort, etc.
*/
export default function buildRequest(state) {
  const {
    current,
    filters,
    resultsPerPage,
    searchTerm,
    sortDirection,
    sortField
  } = state;
  
  const sort = buildSort(sortDirection, sortField);
  //const match = buildMatch(searchTerm);
  const size = resultsPerPage;
  const from = buildFrom(current, resultsPerPage);
  const filter = buildRequestFilter(filters);
  
  const body = {
    // Static query Configuration
    // --------------------------
    // https://www.elastic.co/guide/en/elasticsearch/reference/7.x/search-request-highlighting.html
    highlight: {
      fragment_size: 400,
      number_of_fragments: 1,
      fields: {
        "metadata.eprint.title.*" : { "number_of_fragments" : 1, "fragment_size": 400 },
        "metadata.eprint.abstract.*" : { "number_of_fragments" : 1, "fragment_size": 400 },
        "fulltext.eprint.fulltext.*" : { "number_of_fragments" : 1, "fragment_size": 400 },
        "citation.eprint.*" : { "number_of_fragments" : 1, "fragment_size": 10000 },
      }
  }, 
  
    
    //https://www.elastic.co/guide/en/elasticsearch/reference/7.x/search-request-source-filtering.html#search-request-source-filtering
    _source: [
              "id", 
              "fulltext.eprint",
              "metadata.eprint.title",
              "citation.eprint.es_title",
              "citation.eprint.es_publication",
              "citation.eprint.es_contributors",
              // proxy will read aggs from conf and add them here
            ],
    aggs: {
      // proxy will read aggs from conf and add them here
      // new: sort by value, not by count: https://www.oreilly.com/library/view/elasticsearch-the-definitive/9781449358532/part04ch07.html   
    },

    // JW TEST: ?!?
    export_plugin_selected: "BibTeX",

    // Dynamic values based on current Search UI state
    // --------------------------
    // https://www.elastic.co/guide/en/elasticsearch/reference/7.x/full-text-queries.html
        
    query: { 
      bool: { 
        must: [ 
          { 
            query_string: { 
              query: searchTerm, 
              default_operator: "AND" 
            } 
          }, 
          { 
            "nested": { 
              "path": "metadata.eprint.eprint_status", 
              "query": { 
                "bool": { 
                  "must": [ 
                    { 
                      "term": { 
                        "metadata.eprint.eprint_status.key": "archive" 
                      } 
                    } 
                  ] 
                } 
              } 
            } 
          } 
        ],
        ...(filter && { filter }) 
      } 
    }, 
    
    // https://www.elastic.co/guide/en/elasticsearch/reference/7.x/search-request-sort.html
    ...(sort && { sort }),
    // https://www.elastic.co/guide/en/elasticsearch/reference/7.x/search-request-from-size.html
    ...(size && { size }),
    ...(from && { from })
  };

  return body;
}
