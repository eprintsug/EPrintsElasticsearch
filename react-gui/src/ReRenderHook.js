/*
    like MathJaxReDo.js - rerender after react ist ready
*/

import React, { useEffect } from 'react';

function ReRenderHook(props) {
    let node = React.createRef();  
    
    useEffect(() => {
        renderHook();  
    });  
    const renderHook = () => {    
        

        //re-render Submit Button en/de
        node.current.childNodes[0].elements[1].value = window.label_searchbutton;
        
    }  
    
    return (    
        <div ref={node}>
            {props.children}    
        </div>  
    );
}
    
export default ReRenderHook;
