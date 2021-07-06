
import React, { useState } from 'react';
import Select from 'react-select';


function UZHExportBox(props) {
  
  var ep = props.export;
  var epn = props.export_name;
  var epm = props.export_mimetype;
  var eps = props.export_filename;
  var request = props.request;
  var data = [];  

  // not needed for export
  delete request.aggs;
  request._source = [];
  request._source[0] = 'id';
  delete request.highlight;

  for (let i = 0; i < ep.length; i++) {
    data[i]={
      value: ep[i+1],
      label: epn[i+1],
      filename: eps[i+1],
      mimetype: epm[i+1]
    };
  }  

  const customStyles = {
    /*
    option: (provided, state) => ({
      ...provided,
      borderBottom: '1px dotted pink',
      color: state.isSelected ? 'red' : 'blue',
      padding: 20,
    }),
    */
   
    control: () => ({
      // none of react-select's styles are passed to <Control />
      width: 200,
      //display: flex,
    }),
    /*
    input: styles => ({ ...styles, ...dot() }),
    placeholder: styles => ({ ...styles, ...dot() }),
    singleValue: (styles, { data }) => ({ ...styles, ...dot(data.color) }),

    singleValue: (provided, state) => {
      const opacity = state.isDisabled ? 0.5 : 1;
      const transition = 'opacity 300ms';
      const bg = 'orange';
  
      return { ...provided, opacity, transition, bg };
    }

    
    */
  }
 
  // set value for default selection
  const [selectedValue, setSelectedValue] = useState(1);
  
 
  // handle onChange event of the dropdown
  const handleChange = e => {
    setSelectedValue(e.value);
    console.log("Export selected: "+e.value);
    console.log("Export Filename selected: "+e.filename);
    console.log("Export MimeType selected: "+e.mimetype);
    request.export_plugin_selected = e.value;
    
    
    var img = document.createElement('img');
    img.src = "/images/loading-transparent.gif";
    img.className="export-loader-img";
    document.body.appendChild(img);
    
    
    /* https://stackoverflow.com/questions/32545632/how-can-i-download-a-file-using-window-fetch */

    fetch('/cgi/{repositoryname}/es-{repositoryname}-proxy-export', {
      method: 'POST',
      headers: {
        //'Accept': 'application/json', 
        //'Content-Type': 'application/json',
        'Accept': e.mimetype, 
        'Accept-Encoding': e.mimetype, 
        'Content-Type': e.mimetype,
      },
      body: JSON.stringify(request)
        })
        .then(response => response.blob())
        .then(blob => {
            img.remove();  //download done, remove image
            var url = window.URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = e.filename;
            //a.setAttribute('type', e.mimetype);
            document.body.appendChild(a); // we need to append the element to the dom -> otherwise it will not work in firefox
            a.click();    
            a.remove();  //afterwards we remove the element again             
        });   
  }

  return (
    <div className="export_plugins_select">
      <Select
        placeholder={ep[0]}
        styles={customStyles}
        value={data.find(obj => obj.value === selectedValue)} // set selected value
        options={data} // set list of the data
        onChange={handleChange} // assign onChange function
      />
    </div>
  );

}
 
export default UZHExportBox;
