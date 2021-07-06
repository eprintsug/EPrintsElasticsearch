import buildStateFacets from "./buildStateFacets";


function buildTotalPages(resultsPerPage, totalResults) {
    if (!resultsPerPage) return 0;
    if (totalResults === 0) return 1;
    return Math.ceil(totalResults / resultsPerPage);
}

function buildTotalResults(hits) {
    // bugfix for total results
    
    //bugfix 2020/11/10/JW Result ES6=>ES7: hits.total => hits.total.value
    //return hits.total;
    return hits.total.value;
}

function getHighlight(hit, fieldName) {
    if (
        !hit.highlight ||
        !hit.highlight[fieldName] ||
        hit.highlight[fieldName].length < 1
    ) {
        return;
    }

    return hit.highlight[fieldName][0];
}

function buildResults(hits) {

    
    // nested objects workaround
    // lift nested objects
    for (let i = 0; i < hits.length; i++) {
        hits[i]._source.doi = hits[i]._source.metadata.eprint.doi;
        
        //hits[i]._source.title = hits[i]._source.metadata.eprint.title[0].eng ? 
        //    hits[i]._source.metadata.eprint.title[0].eng : 
        //    hits[i]._source.metadata.eprint.title[0].deu;
        
        /*
        hits[i]._source.contributor_names = "";
        hits[i]._source.contributor_count = hits[i]._source.metadata.eprint.contributor.length;
        for (let j = 0; j < hits[i]._source.contributor_count; j++) {
            hits[i]._source.contributor_names += hits[i]._source.metadata.eprint.contributor[j].name;
            if (j < (hits[i]._source.contributor_count -1)) {hits[i]._source.contributor_names += " - "}
        }
        */
    }
    
    const addEachKeyValueToObject = (acc, [key, value]) => ({
            ...acc,
            [key]: value,
        }
    );
    const toObject = (value, snippet) => {
        return {raw: value, ...(snippet && {snippet})};
    };

    return hits.map(record => {
        return Object.entries(record._source)
            .map(([fieldName, fieldValue]) => [
                fieldName,
                toObject(fieldValue, getHighlight(record, fieldName))
            ])
            .reduce(addEachKeyValueToObject, {});
    });
}

/*
  Converts an Elasticsearch response to new application state

  When implementing an onSearch Handler in Search UI, the handler needs to convert
  search results into a new application state that Search UI understands.

  For instance, Elasticsearch returns "hits" for search results. This maps to
  the "results" property in application state, which requires a specific format. So this
  file iterates through "hits" and reformats them to "results" that Search UI
  understands.

  We do similar things for facets and totals.
*/
export default function buildState(response, resultsPerPage) {
    const results = buildResults(response.hits.hits);
    const totalResults = buildTotalResults(response.hits);
    const totalPages = buildTotalPages(resultsPerPage, totalResults);
    const facets = buildStateFacets(response.aggregations,response.conf_aggs); //JW 2021/07/05

    // ZORA internals: 
    const browser_lang = response.browser_lang;    

    return {
        results,
        totalPages,
        totalResults,
        browser_lang, //JW
        ...(facets && {facets})
    };
}
