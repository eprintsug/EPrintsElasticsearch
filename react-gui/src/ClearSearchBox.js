import React from "react";
import {withSearch} from "@elastic/react-search-ui";

function ClearSearchBox({setSearchTerm}, shouldClearFilters) {
    return (
        <div className="sui-search-box__close">
            <button className="button sui-search-box__close btn btn-primary" 
                onClick={() => setSearchTerm("", {shouldClearFilters: true})}>Clear
            </button>
        </div>
    );
}

export default withSearch(({setSearchTerm, shouldClearFilters}) => ({
    setSearchTerm, shouldClearFilters
}))(ClearSearchBox);
