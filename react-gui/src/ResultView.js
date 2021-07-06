import React from "react";

import Latex from "./MathJaxReDo"; // 2021/01/04/JW ReDo MathJax after async load of content


function testSnippetRaw(snip,raw) { //JW
  return snip ? snip : raw ;
}
  
export default ({ result }) => (
  
  <li className="sui-result">
    <div className="sui-result__body">
      <ul className="sui-result__details">        
        <li>
          <Latex>
            <dl className="dreiklang dreiklang_dl"
              dangerouslySetInnerHTML={{
                __html: testSnippetRaw(result.proxy_citation.snippet,result.proxy_citation.raw)
              }}
            />
          </Latex>          
        </li>
     </ul>
    </div>
  </li>
);
