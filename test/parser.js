var raml = require('raml-parser');
var path = require('path');


var nwd = path.resolve(__dirname);
console.log(nwd);


process.chdir(nwd);

raml.loadFile('/Users/Atoms/workspace/gee/oso/raml2code/test/raml/cats.raml').then( function(data) {
  console.log(data);
}, function(error) {
  console.log('Error parsing: ' + error);
});
